# Inventory

Flat network 192.168.178.0/24 (FRITZ!Box range). Minion ID = hostname = Tofu VM name.

## Salt minions

| Minion | IP | Formulas (`salt/top.sls`) | Services / ports |
|---|---|---|---|
| `salt-master` | .28 | users, wazuh-agent, salt-master | salt-master (gitfs + git_pillar) |
| `homepage` | .23 | users, wazuh-agent, docker, homepage | homepage :3000 |
| `monitoring` | .25 | users, wazuh-agent, docker, grafana, prometheus | Grafana :3000, Prometheus :9090 |
| `arrstack` | .22 | users, wazuh-agent, nfs-mount, docker, arrstack | via gluetun: qBittorrent :8080, Sonarr :8989, Radarr :7878, Prowlarr :9696, Bazarr :6767, slskd :5030; FlareSolverr :8191 (internal) |
| `jellyfin` | .24 | users, wazuh-agent, nfs-mount, docker, jellyfin | Jellyfin :8096 |
| `wazuh` | .27 | users, wazuh | Wazuh indexer/manager/dashboard |

`salt/top.sls` and `pillar/top.sls` are authoritative — update this table when they change.

## Not managed by Salt

| Host | IP | Notes |
|---|---|---|
| OpenBao | .20 | Secrets backend, KV-v2 mount `homelab`. Not a minion, no SSH from Claude sessions — user runs `bao` there. See [secrets.md](secrets.md). |
| TrueNAS | .10 | NFS export `/mnt/pool01/media` (single dataset: `movies/`, `series/`, `music/`, `incomplete/` as plain dirs so hardlinks work). Owner `media` 970:970, mode 775, root squashed. Allowed hosts: .22 (arrstack), .24 (jellyfin). |
| Proxmox / OPNsense | — | Managed by the sibling `IaC-opentofu` / OPNsense repos. |

## External services

- **VPN**: Proton VPN, WireGuard, via gluetun on arrstack. Config generated with NAT-PMP on,
  VPN Accelerator on, NetShield off, Moderate NAT off. Only the private key (OpenBao
  `gluetun/proton`) and the IPv4 address (`10.2.0.2/32`, pillar) are used — gluetun picks the
  server itself (`SERVER_COUNTRIES`), so the server chosen when generating the config doesn't
  matter. IPv6 address from the config must be left out (gluetun refuses to start with it).
- **GitHub**: `pensec1911/IaC-salt`, read-only deploy key from the master.

## Access from a Claude session

- Only `ssh salt-master` (debian@192.168.178.28, key `~/.ssh/homelab`) works. Reach minions
  through Salt: `ssh salt-master "sudo salt <minion> cmd.run '…'"`.
- No GPU on jellyfin (emulated QEMU VGA only) — software transcoding.
