# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## Docker can start before the NFS mount at boot

2026-10-17 arrstack rebooted; `mnt-media.mount` hit its 90 s timeout (NAS slow to answer) and
Docker started the containers anyway, bound to the empty local `/mnt/media`. Fixed by hand
(`systemctl start mnt-media.mount`, restart the media containers). Will recur on any reboot where
the NAS is slow. Affects arrstack and jellyfin.

Proposed fix: a systemd drop-in for `docker.service` with `RequiresMountsFor=<mountpoint>` for
every `nfs_mounts` entry, owned by `formulas/nfs-mount` (pillar-driven, no hardcoded paths).

## Smaller items

- `pillar/GLOBAL.sls`: `ssh_authorized_keys: []` — no SSH key for the per-minion login accounts
  yet.
- Wazuh server not bootstrapped yet (formula rewritten 2026-10-17 after the step-by-step guide,
  not yet applied) — follow `formulas/wazuh/README.md` "Bootstrap". Until then the agents log
  `Unable to connect to enrollment service` every few seconds.
- Pinned arrstack tags (Sonarr 4.0.9, Radarr 5.10.4, Prowlarr 1.24.3, …) are behind upstream.
