# Inventory

Flat network 192.168.178.0/24 (FRITZ!Box range). Minion ID = hostname = Tofu VM name.

VMs, IPs, sizing and the physical hosts are also in NetBox (https://netbox.home.ilpaa.xyz),
written by `IaC-opentofu` on every apply — authoritative for those is the Tofu code. This file
stays the reference for what NetBox doesn't hold: formulas, services/ports, access, NAS
exports, VPN.

## Salt minions

| Minion | IP | Formulas (`salt/top.sls`) | Services / ports |
|---|---|---|---|
| `salt-master` | .28 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, salt-master, orch | salt-master (gitfs + git_pillar); salt-api :8000 (HTTPS, webhooks only); rolling reboot 03:15 Berlin (timer, no port) |
| `homepage` | .23 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, podman, cadvisor, alloy, homepage | homepage :3000 |
| `monitoring` | .25 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, podman, cadvisor, blackbox-exporter, loki, alloy, grafana, prometheus, alertmanager, toolbox, infra-exporters, nfs-mount, backup | Grafana :3000, Prometheus :9090, Alertmanager :9093, blackbox_exporter :9115, Loki :3100; CyberChef :8081, IT-Tools :8082 (`formulas/toolbox`, stateless); pve-exporter :9221, fritz-exporter :9787, graphite-exporter :9108 + Graphite in :9109 tcp/udp (`formulas/infra-exporters`, metrics of Proxmox/FRITZ!Box/TrueNAS) |
| `arrstack` | .22 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, nfs-mount, podman, cadvisor, alloy, arrstack, seerr, backup | Seerr :5055; via gluetun: qBittorrent :8080, Sonarr :8989, Radarr :7878, Prowlarr :9696, Bazarr :6767, slskd :5030; FlareSolverr :8191 (internal); Recyclarr daily (timer, no port) |
| `jellyfin` | .24 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, nfs-mount, podman, cadvisor, alloy, jellyfin, ntfy, healthchecks, backup | Jellyfin :8096; ntfy :8090 (Alertmanager push, LAN only, `formulas/ntfy`); Healthchecks :8000 (job dead-man's switch, `formulas/healthchecks`) |
| `forgejo` | .29 | users, ntp, wazuh-agent, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, nfs-mount, podman, cadvisor, alloy, forgejo, forgejo-runner, netbox, patchmon, tofu-state, backup | Forgejo web :3000, git SSH :2222; Actions runner (no port, jobs in its own dind), Renovate hourly (`homelab/renovate`); NetBox :8000, PatchMon :3001 (their postgres + valkey internal only); Tofu state postgres :5432 (LAN, `formulas/tofu-state`) |
| `wazuh` | .27 | users, ntp, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, wazuh, nfs-mount, backup | dashboard :443, indexer :9200, API :55000, agents :1514 / enrollment :1515 |
| `gateway` | .31 | users, ntp, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, nfs-mount, tailscale, backup | WireGuard wg0 10.99.0.2 → cloud-edge (keys + nftables from IaC-opentofu cloud-init, not Salt); FRITZ!Box routes 10.99.0.0/24 here. Forward rules = the only list of what cloud-edge may reach in the LAN (IaC-opentofu `vms/gateway`). Tailscale subnet router tailnet → LAN (`tag:gateway`, SNAT). No containers. |
| `edge` | .30 | users, ntp, hosts, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, nfs-mount, podman, cadvisor, alloy, caddy, authentik, backup | Caddy :443 (`https://<name>.home.ilpaa.xyz`, wildcard LE cert via Porkbun DNS-01, routes in `pillar/edge-routes.jinja`), :80 → https, metrics :9180. Names resolve via `/etc/hosts` on LAN minions (`formulas/hosts`) and Headscale MagicDNS for tailnet clients. Authentik `https://auth.home.ilpaa.xyz` (server/worker/postgres on the Podman network `edge`, metrics :9300): password + passkey login, forward auth for the `auth: forward` routes. |
| `cloud-edge` | 10.99.0.1 (wg0) | users, ntp, node-exporter, unattended-upgrades, patchmon-agent, healthchecks-ping, salt-minion, podman, cadvisor, alloy, nfs-mount, headscale, backup | Headscale `https://hs.ilpaa.xyz` :443 + DERP (STUN :3478/udp), metrics 10.99.0.1:9090. OCI A1.Flex arm64 (IaC-opentofu `oci/`), reserved public IP behind `hs.ilpaa.xyz` (Tofu output `public_ip`); only 443/tcp, 3478/udp, 51820/udp open (NSG). LAN only through the tunnel; SSH `debian@10.99.0.1` from the LAN. NTP from Oracle (169.254.169.254). |

Every minion: node_exporter :9100; patchmon-agent (no port, outbound WebSocket to PatchMon on
forgejo — only once enrolled, formulas/patchmon-agent README). Container hosts (homepage, monitoring, arrstack, jellyfin, forgejo, edge, cloud-edge — rootful Podman, every container a systemd unit):
cAdvisor :8088. All scraped by Prometheus on monitoring — targets from the Salt Mine (`node_exporter`, `cadvisor` entries), not listed in `pillar/prometheus.sls`. Every homepage item with a status dot is also HTTP-probed via blackbox_exporter by its name (Caddy + certificate + auth), and every route's upstream directly (`blackbox-upstream`) — both `ProbeFailed`.
Container hosts also run Alloy (no port), shipping the journal (container logs included, `job="container"`) to Loki on monitoring
(Grafana → Explore, datasource `Loki`).
arrstack, jellyfin, monitoring, wazuh, forgejo, gateway, edge and cloud-edge (own repo password) back up nightly (~02:00 Berlin) to the NAS via restic
(`formulas/backup`, `BackupFailed` / `BackupStale`), with a weekly restore test (Sunday ~04:00,
`RestoreTestFailed` / `RestoreTestStale`).
Every minion patches itself daily from Debian main + Debian-Security via unattended-upgrades
(`formulas/unattended-upgrades`; Docker/Salt/Wazuh repos excluded). Pending reboots happen
nightly from 03:15 Berlin, one minion at a time, salt-master last (`formulas/orch`;
`RebootRequired` if not).

**Wazuh** (`pillar/features.jinja`): off 2026-11-11, rebuilt and back on 2026-11-26 (VM 109 on
pve01). Dashboard `https://wazuh.home.ilpaa.xyz` (forward auth, login `admin`). Agents on every
minion except cloud-edge (gateway doesn't forward 1514/1515).

`salt/top.sls` and `pillar/top.sls` are authoritative — update this table when they change.

## Names, firewall, remote access

- **Web UIs by name**: `https://<name>.home.ilpaa.xyz` → Caddy on edge (one Let's Encrypt
  wildcard), list in `pillar/edge-routes.jinja` (also Proxmox `pve01`–`pve03`, `truenas`,
  `openbao`). `auth: forward` routes need an Authentik login (password + passkey) first;
  Grafana, Forgejo, NetBox log in via OIDC; Jellyfin, Seerr and `push` (ntfy API) have only
  their own login. Not routed: FRITZ!Box (DNS-rebind protection), Wazuh (off).
- **Name resolution**: `/etc/hosts` on the LAN minions (`formulas/hosts`), Headscale MagicDNS
  (A records + search domain `home.ilpaa.xyz`) for tailnet devices. Porkbun answers unknown
  names with a parking page — anything else resolving them publicly lands there.
- **Proxmox firewall** (IaC-opentofu `firewall.tf`, step 7): every Tofu-managed VM drops
  inbound except its rule list — app ports only from edge (.30) and monitoring (.25), Jellyfin
  :8096 and SSH from the LAN, machine-to-machine (Salt, Loki, Healthchecks, PatchMon, ntfy,
  scrapes) from all minions incl. cloud-edge (10.99.0.1). PVE hosts and OpenBao aren't filtered.
  **A new app port needs a rule there** (patterns.md "Edge routes").
- **Remote access**: Tailscale against Headscale (`hs.ilpaa.xyz`), gateway is the subnet router
  (SNAT → .31). The ACL (`pillar/headscale.sls` `admin_access`) allows the admin's devices
  edge:80/443, SSH to the LAN minions, Proxmox 22/8006, OpenBao 22/8200, forgejo 2222/5432/8000,
  monitoring 9090/9093 (APIs), TrueNAS 22/80/443, FRITZ!Box 53/80/443 — nothing else, also at
  home (the laptop routes the LAN through the tailnet).

## Not managed by Salt

| Host | IP | Notes |
|---|---|---|
| OpenBao | .20 | Secrets backend, KV-v2 mount `homelab`. Not a minion, no SSH from Claude sessions — user runs `bao` there. See [secrets.md](secrets.md). |
| TrueNAS | .10 | NFS export `/mnt/pool01/media` (single dataset: `movies/`, `series/`, `music/`, `incomplete/`, `torrents/` as plain dirs so hardlinks work). Owner `media` 970:970, mode 775, root squashed. Allowed hosts: .22 (arrstack), .24 (jellyfin). Name `https://truenas.home.ilpaa.xyz` (Caddy, forward auth). Reporting → Exporters pushes Graphite to monitoring:9109 (formulas/infra-exporters). Fast sequentially (~110 MB/s), slow for small random writes (~1.3 MB/s) — why qBittorrent downloads to local disk first. Export `/mnt/pool01/backups`: restic repos `<minion>/` (formulas/backup), mounted at `/mnt/backups` on every minion with `backup` (arrstack, jellyfin, monitoring, forgejo, gateway, edge, cloud-edge); owner `restic` 3000:3000, mode 700, Maproot → `restic`, hosts `*` (formulas/backup README "NAS side"). |
| FRITZ!Box | .1 | Router/DHCP; NTP source for every minion (formulas/ntp, no fallback). Metrics via TR-064 (user `prometheus`, read-only) → fritz-exporter on monitoring. |
| Proxmox / OPNsense | — | Managed by the sibling `IaC-opentofu` / OPNsense repos. Proxmox nodes pve01–03 (.11–.13, one cluster; `https://pveNN.home.ilpaa.xyz` via Caddy, API/Tofu on the IP; pve01 32 GB, the others 16 GB): metrics via API token `prometheus@pve!exporter` (PVEAuditor) → pve-exporter on monitoring. |

## External services

- **VPN**: Proton VPN, WireGuard, via gluetun on arrstack. Config generated with NAT-PMP on,
  VPN Accelerator on, NetShield off, Moderate NAT off. Only the private key (OpenBao
  `gluetun/proton`) and the IPv4 address (`10.2.0.2/32`, pillar) are used — gluetun picks the
  server itself (`SERVER_COUNTRIES`), so the server chosen when generating the config doesn't
  matter. IPv6 address from the config must be left out (gluetun refuses to start with it).
- **Forgejo** (`https://git.home.ilpaa.xyz`, SSH `ssh://git@192.168.178.29:2222`; `homelab/IaC-salt`, `homelab/IaC-opentofu`): the source of truth and the deploy
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
- The laptop is a tailnet node (`nix`): only the ACL list above is reachable. App UIs by name
  answer with a redirect to Authentik (no session in a script); Prometheus/Alertmanager APIs
  are open (`/homelab-status`). Anything else on an app port: from the host itself, e.g.
  `ssh salt-master "sudo salt monitoring cmd.run 'curl -s 127.0.0.1:3100/…'"`.
- No GPU on jellyfin (emulated QEMU VGA only) — software transcoding.
