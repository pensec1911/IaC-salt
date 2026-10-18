# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## Security

- **`auto_accept: true` on the master** (`formulas/salt-master/files/auto_accept.conf`, "closed
  homelab LAN"). Any LAN host running salt-minion gets its key accepted and is served the `'*'`
  pillar — that includes the shared login password hash from `pillar/GLOBAL.sls` and the
  wazuh-agent pillar. Options: turn it off and accept keys by hand (`salt-key -a`) after each
  Tofu provision, or `autosign_grains` / pre-seeded keys from Tofu. The start reactor
  (formulas/salt-master) does not widen this — an accepted minion can already pull its own
  highstate/pillar.

## Smaller items

- Start reactor (formulas/salt-master) after a full VM reboot: verified on **jellyfin**
  (2026-10-18) — NFS mount and salt-minion both up at boot+7 s, reactor highstate ran ~45 s
  later (queued behind the start-time drift check), 0 failed / 0 changed, drift 0. Still
  untested on **arrstack** (NFS + VPN sidecar + port forwarding). Check at its next planned
  reboot (`salt-run jobs.list_jobs search_function=state.apply search_target=arrstack`), then
  delete this entry.

- arrstack is on the latest release *within* each major (2026-10-17). Newer majors exist and
  were deliberately not taken: Radarr 6, Prowlarr 2, qBittorrent 5 — each migrates its config/DB
  one-way, so back up `/opt/arrstack/<app>` and read the release notes before bumping.
