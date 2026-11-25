# tailscale formula

Tailscale client from `pkgs.tailscale.com` (not in Debian), logged in to the self-hosted
Headscale (`formulas/headscale`). Used on `gateway` as the subnet router: tailnet → LAN
(`192.168.178.0/24`), SNAT'ed, filtered by gateway's nftables (IaC-opentofu `vms/gateway`)
and the Headscale policy.

## What it manages

- Repo key (`/usr/share/keyrings/tailscale-archive-keyring.gpg`, fetched once), apt source,
  package `tailscale`, service `tailscaled`.
- **Joining** (`up.sls`), only when `login_server` and a resolved `auth_key` are in pillar:
  writes the key to `/etc/tailscale/authkey` (0600), runs `tailscale up` with the pillar's
  flags, deletes the key file. Skipped while `tailscale status` says `Running`, so it runs
  once. Without a key: package + daemon only, a clean highstate.

State that Salt can't rebuild: `/var/lib/tailscale` (node key; backed up). Lost or rebuilt
gateway → new pre-auth key (formulas/headscale README) and remove the old node there.

## Pillar

`pillar/tailscale.sls`; keys in `map.jinja`. `auth_key` from OpenBao `headscale/<minion>`
(created on the Headscale side, 1 h, tagged).

## Changing flags later

`tailscale up` only runs at the first login. For new `advertise_routes`/`advertise_tags` etc.,
on the minion: `sudo tailscale up --reset --login-server=… <all flags>` (or log out, put a
fresh key in OpenBao and re-apply).
