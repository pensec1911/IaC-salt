# Inventory

Flat network 192.168.178.0/24 (FRITZ!Box range). Minion ID = hostname = Tofu VM name.

## Salt minions

| Minion | IP | Formulas (`salt/top.sls`) | Services / ports |
|---|---|---|---|
| `salt-master` | .28 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, salt-master, orch | salt-master (gitfs + git_pillar); salt-api :8000 (HTTPS, webhooks only); rolling reboot 03:15 Berlin (timer, no port) |
| `homepage` | .23 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, docker, cadvisor, alloy, homepage | homepage :3000 |
| `monitoring` | .25 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, docker, cadvisor, blackbox-exporter, loki, alloy, grafana, prometheus, alertmanager, nfs-mount, backup | Grafana :3000, Prometheus :9090, Alertmanager :9093, blackbox_exporter :9115, Loki :3100 |
| `arrstack` | .22 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, nfs-mount, docker, cadvisor, alloy, arrstack, seerr, backup | Seerr :5055; via gluetun: qBittorrent :8080, Sonarr :8989, Radarr :7878, Prowlarr :9696, Bazarr :6767, slskd :5030; FlareSolverr :8191 (internal); Recyclarr daily (timer, no port) |
| `jellyfin` | .24 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, nfs-mount, docker, cadvisor, alloy, jellyfin, backup | Jellyfin :8096 |
| `forgejo` | .29 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, salt-minion, nfs-mount, docker, cadvisor, alloy, forgejo, backup | Forgejo web :3000, git SSH :2222 |
| `wazuh` | .27 | users, ntp, node-exporter, unattended-upgrades, salt-minion, wazuh, nfs-mount, backup | dashboard :443, indexer :9200, API :55000, agents :1514 / enrollment :1515 |

Every minion: node_exporter :9100. Docker hosts (homepage, monitoring, arrstack, jellyfin, forgejo):
cAdvisor :8088. All scraped by Prometheus on monitoring — targets from the Salt Mine (`node_exporter`, `cadvisor` entries), not listed in `pillar/prometheus.sls`. Every homepage item with a status dot is also HTTP-probed via blackbox_exporter (`ProbeFailed`).
Docker hosts also run Alloy (no port), shipping container logs + journal to Loki on monitoring
(Grafana → Explore, datasource `Loki`).
arrstack, jellyfin, monitoring, wazuh and forgejo back up nightly (~02:00 Berlin) to the NAS via restic
(`formulas/backup`, `BackupFailed` / `BackupStale`), with a weekly restore test (Sunday ~04:00,
`RestoreTestFailed` / `RestoreTestStale`).
Every minion patches itself daily from Debian main + Debian-Security via unattended-upgrades
(`formulas/unattended-upgrades`; Docker/Salt/Wazuh repos excluded). Pending reboots happen
nightly from 03:15 Berlin, one minion at a time, salt-master last (`formulas/orch`;
`RebootRequired` if not).

`salt/top.sls` and `pillar/top.sls` are authoritative — update this table when they change.

## Not managed by Salt

| Host | IP | Notes |
|---|---|---|
| OpenBao | .20 | Secrets backend, KV-v2 mount `homelab`. Not a minion, no SSH from Claude sessions — user runs `bao` there. See [secrets.md](secrets.md). |
| TrueNAS | .10 | NFS export `/mnt/pool01/media` (single dataset: `movies/`, `series/`, `music/`, `incomplete/`, `torrents/` as plain dirs so hardlinks work). Owner `media` 970:970, mode 775, root squashed. Allowed hosts: .22 (arrstack), .24 (jellyfin). Fast sequentially (~110 MB/s), slow for small random writes (~1.3 MB/s) — why qBittorrent downloads to local disk first. Export `/mnt/pool01/backups`: restic repos `<minion>/` (formulas/backup), mounted at `/mnt/backups` on arrstack, jellyfin, monitoring, wazuh, forgejo; owner `restic` 3000:3000, mode 700, Maproot → `restic`, hosts `*` (formulas/backup README "NAS side"). |
| FRITZ!Box | .1 | Router/DHCP; NTP source for every minion (formulas/ntp, no fallback). |
| Proxmox / OPNsense | — | Managed by the sibling `IaC-opentofu` / OPNsense repos. |

## External services

- **VPN**: Proton VPN, WireGuard, via gluetun on arrstack. Config generated with NAT-PMP on,
  VPN Accelerator on, NetShield off, Moderate NAT off. Only the private key (OpenBao
  `gluetun/proton`) and the IPv4 address (`10.2.0.2/32`, pillar) are used — gluetun picks the
  server itself (`SERVER_COUNTRIES`), so the server chosen when generating the config doesn't
  matter. IPv6 address from the config must be left out (gluetun refuses to start with it).
- **Forgejo** (.29, `homelab/IaC-salt`, `homelab/IaC-opentofu`): the source of truth and the deploy
  source. Read-only deploy key from the master. A push webhook to salt-api `/hook/git` makes the
  master fetch at once.
- **GitHub**: `pensec1911/IaC-salt`, `pensec1911/IaC-opentofu` are push mirrors of Forgejo
  (sync on every push, PAT `github/mirror`). Never push there directly: the next mirror sync
  overwrites it.

## Access from a Claude session

- Every VM: `ssh -i ~/.ssh/homelab debian@<ip>`, passwordless `sudo` (no root SSH). Also the
  per-minion login `<minion>@<ip>` (`wazuh-admin` on wazuh), same key, `sudo` with the shared
  `users/shared` password. Only
  `salt-master` has a `~/.ssh/config` alias. For anything scripted across minions, go through
  Salt: `ssh salt-master "sudo salt <minion> cmd.run '…'"`.
- No GPU on jellyfin (emulated QEMU VGA only) — software transcoding.
