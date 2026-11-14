# oxidized formula

[Oxidized](https://github.com/ytti/oxidized) pulls the configuration of the network devices that
neither Tofu nor Salt manage, commits every change to a local git repo and pushes it to the
private Forgejo repo `homelab/network-configs` — every config change becomes a diff. One Podman
container (Quadlet unit via `formulas/podman`) on monitoring; oxidized-web, bundled in the image,
serves the device list, versions and diffs on **:8888** (homepage → Infrastructure).

| Container | Image | Port |
|---|---|---|
| `oxidized` | [oxidized/oxidized](https://hub.docker.com/r/oxidized/oxidized) (official, Debian trixie + Ruby) | :8888 (oxidized-web) |

Depends on the `podman` formula only.

## What it manages

Nothing at all until `oxidized:lookup:enabled` — see "Secret guard". Then:

- `oxidized.config` — the check (`test.fail_without_changes` if a key is empty / an unresolved
  `sdb://` URI, the Forgejo key isn't legacy PEM, a device lacks host/host key, or there is no
  device), and under `/opt/oxidized`:
  - `config/` (0755, root, read-only in the container at `/etc/oxidized`): `config`, `router.db`
    (tab-separated: name, IP, model, user, SSH port, key path — no secrets) and
    `.ssh/known_hosts` (Forgejo's SSH host key + every device's, all pinned in pillar).
  - `secrets/` (0700 root): `forgejo`, `forgejo.pub` (deploy key) and `device-<name>` (device SSH
    keys), 0444, each bound read-only into `/keys/` — the podman README pattern for secret files.
  - `data/` (`:U`, owned by the container's mapping): the local repo `network-configs.git` and
    crash files.
- `oxidized.container` — `oxidized` itself as the image's `oxidized` user (30000), not via the
  image's runit/gosu start (that needs root + SETUID/SETGID and a writable root fs). So: podman
  defaults — read-only root, no capabilities, own user namespace. `HOME` and `OXIDIZED_HOME` are
  `/etc/oxidized`: libgit2 (push) and net-ssh (devices) both read `$HOME/.ssh/known_hosts`.
  Restarted on any change of config, router.db, known_hosts or a key.

**How it runs**: every device is fetched once per `interval` (3600 s, Oxidized's default) over
SSH with key auth only (`auth_methods: [publickey]`, no password ever sent) and verified host
keys (`input.ssh.secure`). A changed config is committed and the `githubrepo` hook pushes
(`post_store`) to `ssh://git@192.168.178.29:2222/homelab/network-configs.git` with the deploy
key. Unchanged configs make no commit. A fetch is a few `cat`s over one SSH session — no
sustained load, so no schedule outside 02:00–06:00 is needed.

**Secret guard** (`pillar/oxidized.jinja`, imported by `pillar/oxidized.sls`,
`pillar/homepage.sls`, `pillar/prometheus.sls`, `pillar/backup.sls`): a device counts only when
its pillar data (host, host key) is complete **and** its key `homelab/oxidized/<name>` resolves;
Oxidized runs only with ≥ 1 such device **and** the Forgejo key `homelab/oxidized/forgejo`.
Oxidized refuses to start with zero devices (`source returns no usable nodes`), and without the
push key the history would never leave monitoring — so until both exist, there is no container,
no homepage tile, no Prometheus job, no backup path, and monitoring's hourly self-repair changes
nothing. Removing a secret later does not remove an already deployed container (stop it and
delete `/etc/containers/systemd/oxidized.*` by hand).

## Devices

| Device | Oxidized model | Status |
|---|---|---|
| OPNsense | `opnsense` (SSH exec: `cat /conf/config.xml`, `opnsense-version`; revision timestamps stripped, so no daily noise) | Prepared, off: no OPNsense box is in `inventory.md` yet — `host` and `host_key` in `pillar/oxidized.jinja` are empty. |
| FRITZ!Box | — | **Not supported**: Oxidized 0.37.0 has no FRITZ!Box/AVM model (checked the 198 models in `lib/oxidized/model`). Its export (TR-064 `X_AVM-DE_GetConfigFile`) would need a custom model; see "Open". |
| Omada switches | — | **Not supported**: no Omada model; adopted switches are configured by the Omada controller (.26), whose own auto-backup covers them. Oxidized's `tplink` model is for standalone JetStream CLI. |

Adding a device: an entry in `device_defs` in `pillar/oxidized.jinja` (model, host, username,
port, `host_key` from `ssh-keyscan -t ed25519 <host>`), its key in OpenBao (below), the account
on the device. Device names are file names (`device-<name>`) — letters, digits, `-`.

## Manual steps

The Forgejo API token Claude sessions use has no org scope, and keys/device accounts are
security-critical bootstrap — all by hand, once.

### 1. Forgejo repo + deploy key

1. Forgejo (http://192.168.178.29:3000) → org `homelab` → **New Repository**: name
   `network-configs`, **Private**, no README/.gitignore/license (empty — the first push creates
   `master`). Nobody else gets access: OPNsense's config.xml holds password hashes, API keys,
   VPN and certificate private keys.
2. On the OpenBao host, generate the deploy key — **legacy PEM RSA**: Oxidized pushes with
   Rugged/libssh2, which can't read the OpenSSH key format (oxidized docs, issues #1877/#2324):
   ```sh
   umask 077; d=$(mktemp -d)
   ssh-keygen -q -t rsa -b 4096 -m PEM -N '' -C oxidized@monitoring -f "$d/forgejo"
   cat "$d/forgejo.pub"
   bao kv put -mount=homelab oxidized/forgejo ssh_key=@"$d/forgejo" ssh_key_pub=@"$d/forgejo.pub"
   rm -rf "$d"
   ```
   (`key=@file` reads the value from the file — keeps it out of shell history and argv.)
3. `homelab/network-configs` → Settings → **Deploy keys** → Add: title `oxidized@monitoring`,
   the `.pub` line from step 2, **Enable write access** ✓.

### 2. OPNsense (once the box exists)

1. **System → Access → Users → Add**: username `oxidized`, "Generate a scrambled password" ✓
   (never used — key only), **Login shell `/bin/sh`** (Oxidized runs plain commands over SSH
   exec; the OPNsense menu shell would break that), group: none. Save.
2. Edit `oxidized` → **Effective Privileges** → add only **"System: Shell account access"**
   (what the Oxidized model needs). Save.
3. On the OpenBao host, the device key (ed25519 is fine here — net-ssh reads it):
   ```sh
   umask 077; d=$(mktemp -d)
   ssh-keygen -q -t ed25519 -N '' -C oxidized@monitoring -f "$d/opnsense"
   cat "$d/opnsense.pub"
   bao kv put -mount=homelab oxidized/opnsense ssh_key=@"$d/opnsense"
   ```
   Paste the `.pub` line into the `oxidized` user's **Authorized keys**. Before `rm -rf "$d"`,
   check from that host: `ssh -i "$d/opnsense" oxidized@<opnsense-ip> 'cat /conf/config.xml' | head -3`
   must print XML. If it says permission denied, config.xml isn't readable for a non-admin
   account on your version — then either put `oxidized` into `admins` (it becomes a full admin:
   weigh that) or use OPNsense's own `os-git-backup` plugin instead (pushes config.xml itself;
   drop the device here).
4. **System → Settings → Administration → Secure Shell**: Enable ✓, **Permit root user login ✗**,
   **Permit password login ✗** (keys only), Listen interfaces: LAN.
5. In `pillar/oxidized.jinja`, set `opnsense.host` (its LAN IP) and `opnsense.host_key`
   (`ssh-keyscan -t ed25519 <ip>` → `{'enc': 'ssh-ed25519', 'key': 'AAAA…'}`), commit, push.

The next hourly self-repair on monitoring (or `/deploy monitoring`) starts Oxidized; the first
fetch happens right away. Check: Oxidized UI (homepage → Infrastructure) shows the device with
status `success`, and `homelab/network-configs` has a commit.

## Monitoring

- The homepage tile is HTTP-probed like every other (`ProbeFailed`).
- Prometheus job `oxidized` (`pillar/prometheus.sls`): blackbox module `oxidized_nodes_ok`
  (`pillar/oxidized.sls`) fetches oxidized-web's `/nodes.json` and fails while any device's
  last status is `fail` or `no_connection` (`never` = not fetched yet, passes). Alert
  **`OxidizedFetchFailed`** after 2 h (two hourly cycles, each with 3 retries). Which device: the
  UI. Oxidized has no Prometheus endpoint of its own (0.37.0).
- A failed push isn't in that status — it's in the log: `journalctl -u oxidized | grep -i push`.
  The next config change retries the push (the hook fetches + merges first).

## Backup

`/opt/oxidized/data` (the local repo) is in `pillar/backup.sls` while Oxidized runs. Forgejo
holds a copy, but a rebuilt Oxidized with an empty local repo can't push onto it: its new
commits have no common history with the remote, the hook's merge conflicts and every push is
refused. Restoring the repo avoids that. Without a backup: `git clone --bare` the Forgejo repo
into `/opt/oxidized/data/network-configs.git` before the first start. Config, router.db,
known_hosts and keys are rebuilt by Salt from pillar/OpenBao — not backed up. No SQLite, so no
container stop.

## Open

- FRITZ!Box: a custom Oxidized model (or a timer that pulls the TR-064 export into the same
  repo) — its export is encrypted with an export password, which would then need OpenBao too.
- Push failures don't alert (see Monitoring). If that matters: a `exec` hook on `post_store`
  writing a timestamp a textfile collector reads.
- No auth on oxidized-web (LAN only, read-only views, but it shows the configs — which contain
  secrets once OPNsense is in). Restrict by firewall or a reverse proxy with auth when one exists.

## Updating

Image tag is Renovate-tracked (`map.jinja`). Before a bump, check the release notes for config
schema changes (e.g. `rest:` → `extensions.oxidized-web` in 0.35) and model changes for the
devices in use.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - podman
  - oxidized
```

## Pillar

See `pillar.example.sls`; real values in `pillar/oxidized.sls` and `pillar/oxidized.jinja`.
