# arrstack formula

Runs qBittorrent, Sonarr, Radarr, Prowlarr, and slskd (Soulseek) as Docker containers, all routed
through a Mullvad VPN via [gluetun](https://github.com/qdm12/gluetun). Depends on the `docker`,
`users`, and `nfs-mount` formulas — this formula only handles the six containers and their config.

Unlike `formulas/grafana`/`formulas/prometheus`, this is one formula for a tightly-coupled group
of services (they share gluetun's network namespace) rather than one formula per service.

## Networking model

`gluetun-container` is the only container with its own network stack — everything else attaches
to it via `network_mode: container:gluetun`, so their traffic can only leave through the VPN
tunnel. This has a consequence worth understanding before touching `gluetun.sls`:

**A container sharing another's network namespace can't publish its own ports.** So every WebUI
port (qBittorrent, Sonarr, Radarr, Prowlarr, slskd) is published on `gluetun-container`, not on
the app container it actually belongs to — `port_bindings` in `gluetun.sls` lists all five.

**gluetun's own firewall drops inbound connections by default, even to ports Docker published**,
unless explicitly allowed via `FIREWALL_INPUT_PORTS`. That's the actual mechanism behind "WebUIs
reachable on the LAN, everything else only via the VPN" — it's not a separate exception you have
to build, it's what this one env var (built from the same port values as `port_bindings`, so they
can't drift apart) already does. Nothing else is exposed: qBittorrent's torrent port and slskd's
Soulseek listen port are *not* forwarded, so peer connectivity is NAT'd outbound-only for now (no
port-forwarding — a possible future enhancement, out of scope here).

`prowlarr-container` doesn't get a `media_mount` bind — it only manages indexers and talks to
Sonarr/Radarr over their APIs, it doesn't touch files.

## Dedicated user

Unlike grafana/prometheus (which skip a host account because their images bake in a fixed uid),
these images all support flexible ownership, so a real host account is worth having: `pillar/
arrstack.sls` appends a `media` account to `users:accounts` with **pinned** `uid`/`gid` (970/970 by
default) — pinned, not auto-assigned, because `arrstack:lookup:puid`/`pgid` (fed into PUID/PGID
env vars for the LSIO images, and slskd's `user:` override) has to be a number known at Jinja
render time, the same reasoning as grafana/prometheus's pinned uid/gid. If you change one, change
the other to match.

**NAS-side note**: this repo only manages the client side of the mount (see `formulas/nfs-mount`).
Whatever's exporting `pool01/media` needs to actually allow uid/gid 970 to write to it (TrueNAS
maproot/ACL config) — that's outside this repo's reach, check it if writes start failing with
permission errors.

## Usage

```yaml
# salt/top.sls
'arrstack':
  - users
  - nfs-mount
  - docker
  - arrstack
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/arrstack.sls`
(referenced from `pillar/top.sls`); the NFS mount itself is `pillar/nfs-mount.sls`.

`gluetun:wireguard_private_key` and all four `slskd:*` credentials are required in practice (no
sane default — see `map.jinja`) and must be `sdb://` references, never literal values (CLAUDE.md
"Secrets in pillar"). `wireguard_addresses` comes from the same Mullvad WireGuard config the
private key does — not secret on its own, but account-specific, so it's still pillar data you have
to fill in rather than a real default.

## Things worth double-checking before relying on this

- **Image tags** (`gluetun` `v3.39.1`, `slskd` `0.21.3`, the LSIO images) are pinned to specific
  versions per this repo's convention, but picked without being able to check current releases —
  verify they still exist and bump as needed, same as you'd do for any pinned tag here.
- **slskd's env var names and internal paths** (`SLSKD_SLSKD_USERNAME`/`SLSKD_SOULSEEK_USERNAME`/
  `SLSKD_DOWNLOADS_DIR`/`SLSKD_INCOMPLETE_DIR`, bind target `/app`) are based on general
  familiarity with the project, not verified against its current docs the way the LSIO images and
  gluetun's env vars are — slskd is the newest/least-established image in this stack. Check
  `slskd`'s actual documentation if it doesn't come up cleanly.
