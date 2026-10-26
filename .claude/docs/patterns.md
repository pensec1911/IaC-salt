# Established patterns

Each section: the rule, then where to see it implemented. Read the referenced formula before
building something similar.

## Shared `users` formula for service accounts

Service formulas never create users/groups themselves. `formulas/users/init.sls` loops over
`pillar:users:accounts` (list of `{name, uid?, gid?, group?, home?, shell?, system?, sudo?,
password?, ssh_authorized_keys?}`) and emits `group-<name>` + `user-<name>` states. A consuming
formula declares `require: - user: user-<name>`.

- Each service's `pillar/<name>.sls` **appends** its account(s) to `users:accounts`. This only
  merges across pillar files because the master sets `pillar_merge_lists: True`
  (`formulas/salt-master`); without it only the last file's list survives.
- `uid`/`gid` stay unset (auto) unless a consumer needs the number at Jinja render time (Docker
  `PUID`/`PGID`, a container `user:` override). Then pin it in pillar **and** in the formula's
  `map.jinja`, avoiding 65534/`nobody` and the 1000+ range (the per-minion login account from
  `GLOBAL` lands there).
- Pinned today: `media` = 970:970 (arrstack + jellyfin, owns the NAS media share), `seerr` =
  971:971 (container `user:` override, image default is uid 1000).
- `GLOBAL` creates a sudo login account named after the minion — **unless that name is a
  service's own system user** (packages silently adopt an existing user of their name, turning
  their daemons into a sudo-capable login). Such minions get a renamed login via the map in
  `pillar/GLOBAL.sls` (`wazuh` → `wazuh-admin`). Check this before naming a new VM after its
  service package.
- `users` goes first in the minion's `salt/top.sls` entry.

See `formulas/users/README.md`, `formulas/arrstack` (`media`).

## NFS mounts are Salt state, not Tofu state

"VM X needs share Y at path Z" is pillar data (`nfs_mounts:` list) consumed by
`formulas/nfs-mount` (`mount.mounted`, state ID `nfs-mount-<name>`, fstab-persisted). Consumers
`require: - mount: nfs-mount-<name>`; `nfs-mount` is listed before them in `salt/top.sls`.

- The list lives in whichever pillar file describes the minion (`pillar/nfs-mount.sls` for
  arrstack, inline in `pillar/jellyfin.sls`).
- Consumers that only read get `ro` in the mount opts **and** a `:ro` container bind
  (jellyfin) — arrstack is the only writer on the media share.
- NAS squashes root: create anything on the share as 970 (`setpriv --reuid … install -d`), not
  as root — see `formulas/arrstack/config.sls`.
- Minions whose containers bind a share set `nfs-mount:lookup:required_by: [docker.service]`
  (arrstack, jellyfin): Docker waits for the mounts at boot and fails rather than running on
  the empty mountpoint. If the NAS was down at boot, `systemctl start docker` (or a highstate)
  once it's back.

## VPN sidecar (gluetun)

Containers that must share one VPN tunnel use `network_mode: container:<vpn>`. Consequences:

- Only the VPN container can publish ports — every WebUI port goes in gluetun's
  `port_bindings`.
- gluetun's firewall drops inbound even on published ports unless listed in
  `FIREWALL_INPUT_PORTS` (built from the same values as `port_bindings`, so they can't drift).
- Attached containers must `watch` the gluetun state: when gluetun is recreated their namespace
  is gone and they keep "running" with no network.
- gluetun's kill switch doesn't cover packets of already-open connections when `tun0` drops —
  `gluetun.sls` adds a post-rule dropping the tunnel address as source on `eth0` (arrstack README
  "Leak guard").
- **Port forwarding** (`gluetun:port_forwarding: true`, provider must support it — Proton yes,
  Mullvad no): gluetun picks only PF servers and calls hook scripts that push the (changing)
  forwarded port into qBittorrent via its API. Needs gluetun ≥ v3.41 and qBittorrent's
  "bypass auth for localhost". Placeholders `{{PORT}}`/`{{VPN_INTERFACE}}` in the env must be
  wrapped in `{% raw %}` since the sls is Jinja itself.

See `formulas/arrstack/README.md` ("Networking model", "Port forwarding").

## Security-critical bootstrap stays manual

Where getting something silently wrong is worse than not automating it (TLS cert generation,
an auth-plugin init, credentials Salt can't generate), scope it out of the formula and document
it as a one-time manual step instead of guessing tool invocations. Examples: gitfs deploy key
registration, OpenBao AppRole `secret_id`, Wazuh TLS + indexer security init
(`formulas/wazuh/README.md` "What this formula deliberately does NOT do" is the fullest example),
qBittorrent's localhost-auth toggle.

## Patch, don't replace, a package's shipped config

Native packages ship substantial default config (e.g. Wazuh's `ossec.conf` rules/decoders). When
only some values are pillar-driven, patch them in with `file.blockreplace` (marker-delimited)
instead of a full `file.managed` template that silently drops the rest. Small self-contained
files (`opensearch.yml`) can be fully templated. See `formulas/wazuh`, `formulas/wazuh-agent`.

## Docker images

Images are pinned to a specific tag in `map.jinja` (LSIO images: `<version>-ls<build>` or plain
version). Look up the current tag (Docker Hub / GitHub releases) instead of guessing; bump
deliberately.

## Homepage entries

Every web UI in the homelab is an item in `pillar/homepage.sls` — added in the same change that
brings the UI (new formula, a container added to an existing one, a new Tofu VM or appliance).
Removed when the UI goes away.

- **Group**: the existing one that fits — `Media` (Jellyfin, Seerr), `Arr` (Sonarr, Radarr,
  Prowlarr, Bazarr), `Downloads` (qBittorrent, slskd), `Monitoring` (Grafana, Prometheus,
  Alertmanager, Wazuh), `Proxmox` (nodes), `Infrastructure` (NAS, OpenBao, router, other
  appliances). A new group only if none fits.
- **href**: `http(s)://<IP>:<port>` from `inventory.md` / the formula's `map.jinja` — the URL a
  browser on the LAN uses (arrstack apps: the port gluetun publishes on the host).
- **icon**: a name from [dashboard-icons](https://github.com/homarr-labs/dashboard-icons) —
  check it exists (`curl -I https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/<name>.png`).
- **description**: a few words on what it's for.
- **Status dot** comes for free (`siteMonitor` = href). Links + dots only — no widgets that need
  credentials.
- **No entry** for things without a human-facing UI: internal helpers (FlareSolverr), exporters
  (node_exporter, cAdvisor), APIs.
- A new VM on a Proxmox node: update that node's `description` in the `Proxmox` group too.
- The host isn't reachable / the port is unknown: ask, don't guess the port.

## Backup entries

Every service with state Salt can't rebuild (app config, databases, keys/certs) is in
`pillar/backup.sls` — added in the same change that brings the service. Removed when it goes away.

- **paths**: the data dirs (usually under `/opt/<service>`). Not images, not Salt-rendered config,
  not logs/caches/metadata the app re-fetches → `excludes`.
- **stop_containers**: every container with a SQLite DB in those paths (not safe to copy while
  open). Containers sharing a network namespace (gluetun) stop/start fine; the sidecar stays up.
- **New minion**: `backup` in `salt/top.sls` (after `node-exporter` and `nfs-mount`) and the
  minion in the `backup` list match in `pillar/top.sls`. Nothing on the NAS — hosts are `*`.
- **Validation comes for free**: the weekly restore test (formulas/backup README "Restore test")
  restores the latest snapshot and runs `PRAGMA integrity_check` on every SQLite file;
  `RestoreTestFailed`/`RestoreTestStale` alert. After adding paths, run
  `systemctl start restic-backup.service` then `restic-restore-test.service` once.
- **Postgres/MySQL/other server DBs**: a file copy of a running server isn't consistent and the
  restore test only checks SQLite. Needs a dump step before the run (not built yet) — add it to
  formulas/backup, don't just list the data dir.
- **No entry** for stateless services (exporters, FlareSolverr) or data that's fine to lose
  (Prometheus/Loki TSDB).

## Network topology

Everything Salt manages sits on one flat network (192.168.178.0/24) for now. VLAN-aware design
happens in the OpenTofu/OPNsense repos. **Don't add VLAN-, subnet- or firewall-aware logic to
formulas or pillar.** If segmentation arrives, expect it as pillar data (an interface/IP override
per minion), not as something formulas special-case.
