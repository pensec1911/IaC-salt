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

- Start reactor (formulas/salt-master) untested on a full VM reboot of arrstack/jellyfin — only
  a `salt-minion` restart on homepage (2026-10-18). Open: does the highstate fire before the NFS
  mounts are up, and do `nfs-mount` + the `require: - mount:` chains cope? Check at the next
  planned reboot (`salt-run jobs.list_jobs search_function=state.apply`); if it fails, add a
  delay/retry to the reactor. Delete this entry once verified.

- arrstack is on the latest release *within* each major (2026-10-17). Newer majors exist and
  were deliberately not taken: Radarr 6, Prowlarr 2, qBittorrent 5 — each migrates its config/DB
  one-way, so back up `/opt/arrstack/<app>` and read the release notes before bumping.
