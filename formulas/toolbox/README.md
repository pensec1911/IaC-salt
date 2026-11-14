# toolbox formula

Two browser toolboxes as Podman containers (Quadlet units via `formulas/podman`), so encoding,
hashing, JWT/certificate inspection, regex, cron and subnet maths happen on the LAN instead of
pasting secrets into random websites:

- [CyberChef](https://github.com/gchq/CyberChef) (`ghcr.io/gchq/cyberchef`) — :8081
- [IT-Tools](https://github.com/CorentinTh/it-tools) (`ghcr.io/corentinth/it-tools`) — :8082

Both are static web apps served by nginx; everything runs in the browser, nothing is sent back
to the server. Depends on the `podman` formula only. Runs on monitoring (light container host;
homepage is full, see `.claude/docs/capacity.md`).

## What it manages

- `toolbox.cyberchef` — `cyberchef`, as the image's uid 101 (nginx-unprivileged), read-only
  root, no capabilities, 8080 inside → `host_port` 8081.
- `toolbox.it_tools` — `it-tools`, stock nginx image: read-only root plus a tmpfs on
  `/var/cache/nginx`, and only the capabilities nginx's root master needs (bind :80, drop
  workers to uid 101, chown their temp dirs, signal them) — all inside its own user namespace.
  80 inside → `host_port` 8082.

No config files, no volumes, no users.

## Backup

None: both containers are stateless (no volumes, nothing on the host), Salt rebuilds them
completely. Hence no entry in `pillar/backup.sls`.

## Manual steps

None. After the apply: both homepage items (group `Tools`) show a green dot, and
`systemctl status cyberchef it-tools` on monitoring.

## Open

- Plain HTTP, no login — fine for tools that run client-side; goes behind the reverse proxy /
  SSO once that exists.
- IT-Tools upstream hasn't tagged a release since 2024-10; Renovate picks up a new
  `<date>-<commit>` tag if one appears (`renovate.json`).

## Usage

```yaml
# salt/top.sls
'monitoring':
  - podman
  - toolbox
```

## Pillar

None required; overrides in `pillar.example.sls`.
