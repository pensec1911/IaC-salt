# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## wazuh-agent won't start (all agent minions)

Since the agent package actually got installed (2026-10-17, first seen on arrstack + jellyfin):

```
wazuh-agentd: ERROR: (1230): Invalid element in the configuration: 'client'.
wazuh-agentd: ERROR: (1215): No client configured. Exiting.
```

Likely `formulas/wazuh-agent/config.sls`'s `file.blockreplace` puts the `<client>` block outside
the `<ossec_config>` root, or duplicates/nests it with the shipped one. Every highstate on an
agent minion currently ends with 1 failed state (`wazuh-agent` service) because of this.

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
- `pillar/wazuh.sls`: `admin_dn`/`node_dn` must match the Wazuh TLS certs; TLS bootstrap still
  manual and not done (see `formulas/wazuh/README.md`).
- Pinned arrstack tags (Sonarr 4.0.9, Radarr 5.10.4, Prowlarr 1.24.3, …) are behind upstream.
