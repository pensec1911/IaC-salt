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

- **qBittorrent's WebUI freezes while it moves a finished torrent to the NAS** (2026-10-20,
  19:37–19:44, two South Park season packs): the move from local `incomplete_dir` to
  `/media/torrents` blocks qBittorrent 4.6's main loop — WebUI/API don't answer (LAN timeout,
  gluetun's PF hook `signal: killed`), log shows a gap and then "System wake-up event detected".
  Comes back by itself when the move is done; roughly minutes per tens of GB at the NAS's
  ~110 MB/s. Inherent to the local-disk-then-move design (arrstack README). Options if it
  bothers: qBittorrent 5 (see major bumps below — unverified whether it moves off the main
  thread), or accept it.
- **Proton NAT-PMP renewals fail intermittently** (`recvfrom: connection refused` to
  `10.2.0.1:5351`, several times an hour on 2026-10-20). gluetun retries and gets the same port
  back within seconds, so qBittorrent keeps its listen port — noise, not an outage.
- arrstack is on the latest release *within* each major (2026-10-17). Newer majors exist and
  were deliberately not taken: Radarr 6, Prowlarr 2, qBittorrent 5 — each migrates its config/DB
  one-way, so run a fresh backup first (`systemctl start restic-backup.service`, formulas/backup)
  and read the release notes before bumping.
