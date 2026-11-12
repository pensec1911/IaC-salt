# podman formula

The container runtime of every container host: rootful Podman (Debian trixie, 5.4.2) with
[Quadlet](https://docs.podman.io/en/v5.4.2/markdown/podman-systemd.unit.5.html) units. Every
container is a systemd service named like the container (`systemctl status homepage`), logging to
the journal. Formulas don't write Quadlet files themselves: they hand a container spec from their
`map.jinja` to the `container` macro, which renders the unit and manages it.

Replaced `formulas/docker` (2026-11). That formula stays in the repo, but no minion applies it.

## What it manages

- `podman.install` — `podman`, `crun`, `netavark`, `aardvark-dns`, `catatonit`.
- `podman.config` — the `containers` line in `/etc/subuid` and `/etc/subgid` (the range
  `--userns=auto` carves per-container user namespaces from; Podman 5.4.2 looks for that name —
  the `storage` in the shipped `storage.conf` comment is stale), and
  `/etc/containers/containers.conf.d/50-salt.conf` (`log_driver = journald`,
  `firewall_driver = nftables`).
- `podman.migrate` — on a host that still has Docker: stops and disables `docker.socket`,
  `docker.service` and `containerd.service`, then removes Docker's leftover iptables tables (its
  `FORWARD` policy `DROP` blocks all forwarded traffic of netavark's bridge — containers would
  have no egress). No-op without Docker. See "Migration from Docker".
- `macros.jinja` — `container(id, spec, require=[], watch=[])` and `network(id, name)`.

## The container macro

```jinja
{% from "podman/macros.jinja" import container with context %}
{{ container('homepage-container', spec,
             require=[{'file': 'homepage-settings.yaml'}],
             watch=[{'file': 'homepage-settings.yaml'}]) }}
```

States it creates (`<id>` is the first argument; other states refer to the container as
`service: <id>`):

| State | What |
|---|---|
| `<id>-image` | `podman pull`, only if the image isn't there — a tag bump pulls before the restart, a failed pull is a failed state |
| `<id>-env` / `<id>-secret-env` | `/etc/containers/systemd/<name>.env` (0644, diffed) and `.secret.env` (0600, no diff, only with `secret_env`) |
| `<id>-quadlet` | `/etc/containers/systemd/<name>.container` |
| `<id>-daemon-reload` | runs the Quadlet generator when the unit file changed |
| `<id>` | `service.running <name>`, restarted by any change above or in `watch` |

No `enable`: generated units can't be enabled, the unit's `[Install] WantedBy=` starts it at boot.
Environment goes through files on purpose: `Environment=` lands on podman's command line
(`ps`, `/run/systemd/generator/*.service`, world-readable) and systemd would expand `%` and `$`
in it.

### Container spec

Defaults in `map.jinja` (`container`); a formula sets what it needs, plus a `podman` (or
`<name>_podman`) dict in its own `map.jinja` that is merged last, so pillar can override any key
per container.

| Key | Default | Quadlet |
|---|---|---|
| `name`, `image`, `tag` | — | `ContainerName=` (= unit name), `Image=` (always fully qualified — Debian ships no short-name search list) |
| `user` | none | `User=`/`Group=` from `uid:gid` |
| `userns` | `auto` | `UserNS=`; `host` or `container:<name>` used as given |
| `keep_uids`, `keep_gids` | `[]` | with `auto`: `uidmapping=N:N:1` / `gidmapping=N:N:1` — host id N is id N in the container |
| `no_new_privileges` | `True` | `NoNewPrivileges=true` |
| `drop_caps` / `cap_add` | `[ALL]` / `[]` | `DropCapability=` / `AddCapability=` |
| `read_only` | `True` | `ReadOnly=true` + `ReadOnlyTmpfs=true` (tmpfs on `/tmp`, `/run`, `/var/tmp`) |
| `privileged` | `False` | `PodmanArgs=--privileged` |
| `ports`, `volumes`, `tmpfs`, `devices`, `group_add` | `[]` | `PublishPort=`, `Volume=`, `Tmpfs=`, `AddDevice=`, `GroupAdd=` |
| `env` / `secret_env` | `{}` | `EnvironmentFile=` (see above) |
| `command` | `[]` | `Exec=` (quoted, `%`/`$` escaped) |
| `network` | default bridge | `Network=` — `<name>.network` (see `network` macro) or `<container>.container` (its namespace) |
| `hostname` | — | `HostName=` |
| `podman_args` | `[]` | `PodmanArgs=` |
| `unit` | `{}` | extra `[Unit]` lines, `{'After': ['x.service'], …}` |
| `wanted_by` | `[multi-user.target]` | `[Install] WantedBy=` |
| `restart`, `timeout_start_sec`, `stop_timeout` | `always`, `900`, `60` | `Restart=`, `TimeoutStartSec=`, `StopTimeout=` |

`network(id, name)` writes `<name>.network`: a bridge with DNS by container name (aardvark-dns),
the replacement for a private docker network. Containers join with `network: '<name>.network'`;
Quadlet starts `<name>-network.service` before them.

## User namespaces and file ownership

Every container gets its own range from the `containers` subid range: root and every other id
inside is an unprivileged sub-UID on the host. What that means for data on the host:

- **The app runs as a pinned id** (users-formula account, or 65534/472 for the monitoring
  images): `keep_uids`/`keep_gids` map exactly that id 1:1. Files stay owned by it on the host;
  Salt's `file.directory user:` states, NFS (`root_squash`, media 970) and backups don't change.
- **The image's own service user** (postgres 70, valkey 999, netbox 999, alloy's root): a `:U`
  volume hands the directory to whatever the container's mapping is at start (recursive chown on
  every start — fine for small local dirs). Salt then only creates the directory, without
  `user:`/`group:`, or the two would flip ownership on every run. Two containers sharing one `:U`
  directory share one user namespace (`userns: container:<name>`, see netbox's worker).
- **Never `:U` on NFS** (root_squash refuses the chown; it would rewrite the library) **and never
  map host 999** (that's `salt` on every minion).
- **Read-only config from Salt**: root-owned, 0644 (0444 for secret files in a 0700 dir), bound
  `:ro` — readable through the "other" bits.

## Logs

journald log driver: every line is in the host journal with `CONTAINER_NAME=<name>`.
`journalctl -u <name>` or `journalctl CONTAINER_NAME=<name>`. `formulas/alloy` ships it to Loki
as `job="container"`, `container=<name>`.

## Migration from Docker

`salt/top.sls` lists `podman` where `docker` was. The first highstate stops Docker (its containers
stay in `/var/lib/docker`, stopped), clears its firewall leftovers and starts the Quadlet units on
the same ports, binds and data. Per host:

1. Out of self-repair first (`pillar/top.sls`), so a push doesn't start it on its own; then
   `/deploy <minion>`.
2. Afterwards a reboot proves boot order (mounts, networks, `BindsTo`).
3. **Manual, once the host has run on Podman for a while** — not done by Salt, it's the way back:
   `apt purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`,
   `rm -rf /var/lib/docker /var/lib/containerd /etc/docker /etc/apt/sources.list.d/docker.list`.

**Rollback** (before step 3): `systemctl stop <units>`, remove their files from
`/etc/containers/systemd/`, `systemctl daemon-reload`, revert the commit, put `docker` back in
`salt/top.sls`, `systemctl enable --now docker`, then a highstate (docker_container recreates
everything).

## Day to day

- `podman ps`, `podman logs <name>`, `podman exec -it <name> sh` — as with docker.
- Restart: `systemctl restart <name>` (not `podman restart`; a `podman stop` is undone by
  `Restart=always` at once).
- The generated unit: `systemctl cat <name>`; generator errors: `journalctl -b | grep quadlet`,
  or `/usr/libexec/podman/quadlet -dryrun`.
- Old images pile up after tag bumps: `podman image prune -a` (nothing does it automatically yet).

## Pillar

None required. `pillar.example.sls` lists the overrides under `podman:lookup`.
