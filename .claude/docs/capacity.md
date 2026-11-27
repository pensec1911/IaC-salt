# Capacity — hardware budget for new services

Read before placing a new service or container. Live numbers:
`python3 .claude/skills/roadmap-autopilot/capacity.py` (Prometheus 7-day peaks + Tofu
`memory_mb` per Proxmox node).

## Hardware

Three Proxmox nodes, no shared storage: `pve01` **32 GB** RAM (upgraded 2026-11-26),
`pve02` and `pve03` 16 GB each. `IaC-opentofu` `outputs.tf` `node_memory_mb` holds these numbers;
its `tests/fleet.tftest.hcl` blocks more VM RAM on a node than it has (unmanaged VMs from
`netbox.tf` included).

Allocated today (2026-11-27): pve01 21 GB (homepage 1, gateway 1, edge 4, openbao 1, wazuh 8, docs 6), pve02 12 GB (jellyfin, monitoring, salt-master 4 each),
pve03 10 GB (forgejo 6, arrstack 4). pve01 is the node with room for a new VM or a resize.
Allocation and placement are Tofu's (`IaC-opentofu/vms/<name>/main.tf`); NetBox mirrors them.

## Rules

A change may add a service only if **all** of these still hold afterwards:

1. **VM RAM**: 7-day peak used + estimates of every planned addition (table below) ≤ **80 %** of
   the VM's RAM.
2. **VM disk**: root fs keeps ≥ **5 GB** free after images + data (pulled images count; check
   the image size, don't guess).
3. **Node RAM**: allocated `memory_mb` per node ≤ physical RAM − 2 GB for the PVE host:
   **pve01 30 GB**, **pve02/pve03 14 GB**.
   Nothing is reserved for wazuh — it may come back some day, but then it gets its own
   capacity decision; until then its RAM counts as free.
4. **CPU**: no service with sustained load (scanners, indexers, transcoders) on a 1–2 core VM
   without a schedule outside 02:00–06:00 Berlin (backups, restore test, reboots, enforce window).
5. **Placement**: not on `homepage` (1 GB, full); `forgejo` only for things that belong to Git/CI
   (disk is tight). Alerting/heartbeat services not on `monitoring` (they must outlive it).
   `salt-master` runs no containers.

If no VM fits: don't squeeze. Stop and propose the Tofu change (resize or new VM, which node)
— that's the user's call, Tofu changes aren't part of an autopilot run.

Services that blow the budget anyway (Dependency-Track ~4 GB, Greenbone 4–8 GB, a k3s cluster)
wait for a capacity decision; say so in the roadmap entry instead of building them.

## Typical footprints (steady state, for estimates)

| Kind | RAM |
|---|---|
| static web UI (nginx/Caddy serving files) | 20–50 MB |
| Go single binary (ntfy, exporters, rest-server) | 30–100 MB |
| Python/Django app + SQLite (healthchecks) | 100–200 MB |
| Ruby app (Oxidized) | 150–300 MB |
| Postgres | 100–300 MB |
| Java app (Dependency-Track) | 2–4 GB |

Measure after deploy: cAdvisor `container_memory_working_set_bytes{name=~".*<service>.*"}`.

## Planned additions (not yet merged)

Each autopilot item appends its row here in its own branch, so stacked branches carry the sum.
Delete a row once the service is merged and its real usage shows in the 7-day peak.

| Item | Minion | Est. RAM | Est. disk | PR |
|---|---|---|---|---|

_None open._ Measured 2026-11-26: edge 1.75 of 3.9 GB used with Caddy + Authentik (45 %), 12.5 GB
disk free before the Authentik image; cloud-edge (Headscale) outside the PVE budget.
