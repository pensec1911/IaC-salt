# Inventory

Flat network 192.168.178.0/24 (FRITZ!Box range). Minion ID = hostname = Tofu VM name.

## Salt minions

| Minion | IP | Formulas (`salt/top.sls`) | Services / ports |
|---|---|---|---|
| `salt-master` | .28 | users, wazuh-agent, node-exporter, salt-minion, salt-master | salt-master (gitfs + git_pillar) |
| `homepage` | .23 | users, wazuh-agent, node-exporter, salt-minion, docker, cadvisor, homepage | homepage :3000 |
| `monitoring` | .25 | users, wazuh-agent, node-exporter, salt-minion, docker, cadvisor, grafana, prometheus, alertmanager | Grafana :3000, Prometheus :9090, Alertmanager :9093 |
| `arrstack` | .22 | users, wazuh-agent, node-exporter, salt-minion, nfs-mount, docker, cadvisor, arrstack, seerr | Seerr :5055; via gluetun: qBittorrent :8080, Sonarr :8989, Radarr :7878, Prowlarr :9696, Bazarr :6767, slskd :5030; FlareSolverr :8191 (internal) |
| `jellyfin` | .24 | users, wazuh-agent, node-exporter, salt-minion, nfs-mount, docker, cadvisor, jellyfin | Jellyfin :8096 |
| `wazuh` | .27 | users, node-exporter, salt-minion, wazuh | dashboard :443, indexer :9200, API :55000, agents :1514 / enrollment :1515 |

Every minion: node_exporter :9100. Docker hosts (homepage, monitoring, arrstack, jellyfin):
cAdvisor :8088. All scraped by Prometheus on monitoring — targets from the Salt Mine (`node_exporter`, `cadvisor` entries), not listed in `pillar/prometheus.sls`.

`salt/top.sls` and `pillar/top.sls` are authoritative — update this table when they change.

## Not managed by Salt

| Host | IP | Notes |
|---|---|---|
| OpenBao | .20 | Secrets backend, KV-v2 mount `homelab`. Not a minion, no SSH from Claude sessions — user runs `bao` there. See [secrets.md](secrets.md). |
| TrueNAS | .10 | NFS export `/mnt/pool01/media` (single dataset: `movies/`, `series/`, `music/`, `incomplete/`, `torrents/` as plain dirs so hardlinks work). Owner `media` 970:970, mode 775, root squashed. Allowed hosts: .22 (arrstack), .24 (jellyfin). Fast sequentially (~110 MB/s), slow for small random writes (~1.3 MB/s) — why qBittorrent downloads to local disk first. |
| Proxmox / OPNsense | — | Managed by the sibling `IaC-opentofu` / OPNsense repos. |

## External services

- **VPN**: Proton VPN, WireGuard, via gluetun on arrstack. Config generated with NAT-PMP on,
  VPN Accelerator on, NetShield off, Moderate NAT off. Only the private key (OpenBao
  `gluetun/proton`) and the IPv4 address (`10.2.0.2/32`, pillar) are used — gluetun picks the
  server itself (`SERVER_COUNTRIES`), so the server chosen when generating the config doesn't
  matter. IPv6 address from the config must be left out (gluetun refuses to start with it).
- **GitHub**: `pensec1911/IaC-salt`, read-only deploy key from the master.

## Access from a Claude session

- Every VM: `ssh -i ~/.ssh/homelab debian@<ip>`, passwordless `sudo` (no root SSH). Also the
  per-minion login `<minion>@<ip>` (`wazuh-admin` on wazuh), same key, `sudo` with the shared
  `users/shared` password. Only
  `salt-master` has a `~/.ssh/config` alias. For anything scripted across minions, go through
  Salt: `ssh salt-master "sudo salt <minion> cmd.run '…'"`.
- No GPU on jellyfin (emulated QEMU VGA only) — software transcoding.
