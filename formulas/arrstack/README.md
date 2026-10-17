# arrstack formula

Runs qBittorrent, Sonarr, Radarr, Prowlarr, Bazarr, FlareSolverr and slskd (Soulseek) as Docker containers, all routed
through a VPN (currently Proton VPN) via [gluetun](https://github.com/qdm12/gluetun). Depends on the `docker`,
`users`, and `nfs-mount` formulas — this formula only handles the eight containers and their config.

Unlike `formulas/grafana`/`formulas/prometheus`, this is one formula for a tightly-coupled group
of services (they share gluetun's network namespace) rather than one formula per service.

## Networking model

`gluetun-container` is the only container with its own network stack — everything else attaches
to it via `network_mode: container:gluetun`, so their traffic can only leave through the VPN
tunnel. This has a consequence worth understanding before touching `gluetun.sls`:

**A container sharing another's network namespace can't publish its own ports.** So every WebUI
port (qBittorrent, Sonarr, Radarr, Prowlarr, Bazarr, slskd) is published on `gluetun-container`, not on
the app container it actually belongs to — `port_bindings` in `gluetun.sls` lists all six.

**gluetun's own firewall drops inbound connections by default, even to ports Docker published**,
unless explicitly allowed via `FIREWALL_INPUT_PORTS`. That's the actual mechanism behind "WebUIs
reachable on the LAN, everything else only via the VPN" — it's not a separate exception you have
to build, it's what this one env var (built from the same port values as `port_bindings`, so they
can't drift apart) already does. Nothing else is exposed on the LAN side. On the VPN side,
qBittorrent's torrent port is reachable only with `gluetun:port_forwarding` on (below); slskd's
Soulseek listen port is never forwarded.

### Port forwarding

With `gluetun:port_forwarding: true` (only for providers that support it — Proton yes, Mullvad
no longer), gluetun sets `VPN_PORT_FORWARDING=on` + `PORT_FORWARD_ONLY=on` (so it only picks
servers that support it) and opens the forwarded port in its own firewall itself. The provider
assigns a random port that can change on reconnect, so gluetun calls
`/gluetun/qbittorrent-port-{up,down}.sh` (written by `gluetun.sls`) whenever it does, which set
qBittorrent's listen port and bind it to the VPN interface via the WebUI API. Needs gluetun
≥ v3.41 (`VPN_PORT_FORWARDING_UP_COMMAND` is v3.40, the `{{PORT}}` placeholder v3.41).

**One-time manual step:** the hooks call the API unauthenticated, so in qBittorrent tick
*Tools → Options → WebUI → "Bypass authentication for clients on localhost"*. That only exempts
127.0.0.1 — i.e. the containers sharing gluetun's namespace — not LAN clients, which reach the
WebUI through Docker's port publish. Without it the hook fails with a 403 in the gluetun log and
qBittorrent keeps its old port. Not automated because qBittorrent rewrites its config file on
exit, so a Salt-managed edit races the running container.

`prowlarr-container` doesn't get a `media_mount` bind — it only manages indexers and talks to
Sonarr/Radarr over their APIs, it doesn't touch files.

`flaresolverr-container` solves Cloudflare challenges for Prowlarr's indexers. Its port is
deliberately *not* published — only Prowlarr uses it. In Prowlarr: Settings → Indexers → + →
FlareSolverr, host `http://localhost:8191`, give it a tag, and put that tag on the indexers that
need it.

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
sane default — see `map.jinja`) and must be `sdb://` references, never literal values (.claude/docs/secrets.md). `wireguard_addresses` comes from the same WireGuard config the
private key does — not secret on its own, but account-specific, so it's still pillar data you have
to fill in rather than a real default.

## Things worth double-checking before relying on this

- **Image tags** (`gluetun` `v3.41.3`, `slskd` `0.21.3`, the LSIO images) are pinned to specific
  versions per this repo's convention, but picked without being able to check current releases —
  verify they still exist and bump as needed, same as you'd do for any pinned tag here.
- **slskd's env var names** are verified against the running image (`slskd --envars`):
  `SLSKD_USERNAME`/`SLSKD_PASSWORD` (web UI) and `SLSKD_SLSK_USERNAME`/`SLSKD_SLSK_PASSWORD`
  (Soulseek). Unknown `SLSKD_*` vars are ignored silently — a typo means the default web login
  `slskd`/`slskd` and no Soulseek connection, not an error. Re-check after bumping the tag.
