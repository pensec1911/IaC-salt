# infra-exporters formula

Prometheus exporters for the hosts everything else depends on but that aren't Salt minions —
the Proxmox nodes, the FRITZ!Box and TrueNAS. Before this they were only TLS/HTTP-probed. Three
Podman containers (Quadlet units via `formulas/podman`) on monitoring, scraped by
`formulas/prometheus` (jobs and rules in `pillar/prometheus.sls`).

| Container | Image | Port | Source |
|---|---|---|---|
| `pve-exporter` | [prompve/prometheus-pve-exporter](https://github.com/prometheus-pve/prometheus-pve-exporter) | :9221 | PVE API, read-only token; Prometheus passes each node as `?target=` |
| `fritz-exporter` | [pdreker/fritz_exporter](https://github.com/pdreker/fritz_exporter) | :9787 | TR-064 + web UI of the FRITZ!Box, read-only user |
| `graphite-exporter` | [prom/graphite-exporter](https://github.com/prometheus/graphite_exporter) | :9108 (metrics), :9109 tcp/udp (Graphite in) | TrueNAS pushes its Netdata reporting data (Reporting → Exporters) |

Depends on the `podman` formula only.

## What it manages

- `infra-exporters.config` — `config_dir` and the secrets check (`test.fail_without_changes` if
  an enabled exporter's credential is empty or an unresolved `sdb://` URI).
- `infra-exporters.pve` — `pve-exporter`, configured by env (`PVE_USER`, `PVE_TOKEN_NAME`,
  `PVE_VERIFY_SSL=false` — the nodes' certs are self-signed); the token value is in the 0600
  `.secret.env`. **Only when `pve.enabled`.**
- `infra-exporters.fritzbox` — `fritz-exporter`, one device by env (`FRITZ_*`), password in the
  0600 `.secret.env`. **Only when `fritzbox.enabled`.**
- `infra-exporters.truenas` — the Graphite→Prometheus mapping of
  [Supporterino/truenas-graphite-to-prometheus](https://github.com/Supporterino/truenas-graphite-to-prometheus)
  (release v2.2.1, sha256-pinned, downloaded to `config_dir`) and `graphite-exporter` with it,
  strict match (unmapped paths are dropped), series expire 5 min after the last push.

All three run with the podman defaults: read-only root, no capabilities, own user namespace.

**Secret guard**: `pillar/infra-exporters.sls` sets `pve.enabled` / `fritzbox.enabled` only
once the OpenBao secret resolves, and `pillar/prometheus.sls` adds the `pve` / `fritzbox` scrape
job and rules under the same condition. Before that, monitoring's highstate (hourly self-repair)
changes nothing for them. Removing a secret later does not remove an already deployed container
(stop it and delete `/etc/containers/systemd/<name>.*` by hand). The TrueNAS part needs no
secret and is always on.

## Metrics and alerts

Names checked against the exporters' source / the mapping file:

- **Proxmox** (`job="pve"`): `pve_up`, `pve_memory_usage_bytes`/`pve_memory_size_bytes`,
  `pve_disk_usage_bytes`/`pve_disk_size_bytes`, `pve_cpu_usage_ratio`, … keyed by `id`
  (`node/pve01`, `storage/pve01/local`, `qemu/101`). The nodes form one cluster, every node is
  scraped with `cluster=1`, so cluster series come three times (`instance` = the node asked) —
  rules use `max by (id)`. Alerts: `PveNodeDown`, `PveNodeMemoryHigh` (> 90 % for 15 min),
  `PveStorageAlmostFull` (> 90 %).
- **FRITZ!Box** (`job="fritzbox"`, exporter 4.x labels): `fritz_device_reachable`,
  `fritz_wan_phys_link_status` (DSL sync / line up), `fritz_ppp_connection_state`,
  `fritz_dsl_*`, `fritz_wan_data_bytes_total`. Alerts: `FritzboxUnreachable`,
  `FritzboxWanLinkDown`, `FritzboxInternetDisconnected` (line up, PPP down).
- **TrueNAS** (`job="truenas"`, `honor_labels` — `instance` is the hostname set in TrueNAS):
  `zfs_pool{pool,state}` (1 = current state), `disk_temperature{serial}`, plus CPU/RAM/network/
  disk I/O series of the mapping. Alerts: `TruenasPoolNotOnline`, `TruenasDiskHot` (> 55 °C for
  30 min), `TruenasPoolStateMissing` (no pool state for 6 h — push not set up, or Netdata's
  `zfspool` chart missing; fires until the manual steps below are done).
- **Not covered**: SMART health/failing attributes — the Graphite stream has only the
  temperature. TrueNAS' own alerts (SMART test results, pool) stay the source for that;
  Scrutiny would be the dedicated SMART UI (not built).

## Manual steps

### Proxmox: read-only API token

On any PVE node (it's one cluster, users and ACLs are cluster-wide), as root:

```sh
pveum user add prometheus@pve --comment "Prometheus pve-exporter (read-only)"
pveum acl modify / --users prometheus@pve --roles PVEAuditor
pveum user token add prometheus@pve exporter --privsep 0
```

`--privsep 0`: the token has exactly the user's rights (PVEAuditor on `/`, read-only); with
privilege separation it would need its own ACL on top. The last command prints the token
`value` (UUID) once. On the OpenBao host:

```sh
bao kv put -mount=homelab proxmox/exporter token_value=-   # paste the UUID, Ctrl-D (twice if no newline)
bao kv get -mount=homelab proxmox/exporter
```

### FRITZ!Box: read-only user, TR-064 on

1. Password first (max. 32 characters — 16 bytes hex is exactly 32), on the OpenBao host:
   ```sh
   bao kv put -mount=homelab fritzbox/exporter password="$(openssl rand -hex 16)"
   bao kv get -mount=homelab -field=password fritzbox/exporter
   ```
2. FRITZ!Box UI (http://192.168.178.1) → **System → FRITZ!Box-Benutzer → Benutzer hinzufügen**:
   name `prometheus`, the password from step 1, **"Zugang auch aus dem Internet erlaubt" off**,
   rights: only **"FRITZ!Box Einstellungen"** (untick everything else the dialog offers —
   Sprachnachrichten/Faxe/Anrufliste, Smart Home, NAS, VPN). Apply, confirm on the box if asked.
3. **Heimnetz → Netzwerk → Netzwerkeinstellungen → Heimnetzfreigaben**: tick **"Zugriff für
   Anwendungen zulassen"** (TR-064). Apply.

The next hourly self-repair on monitoring starts `fritz-exporter` and adds the job; check
`curl -s http://192.168.178.25:9787/metrics | grep fritz_device_reachable` (1).

### TrueNAS: Graphite push

1. **Reporting → Exporters → Add**: Name `prometheus`, Type **GRAPHITE**, Destination IP
   `192.168.178.25`, Destination Port `9109`, Prefix **`truenas`** (the mapping requires it),
   Namespace empty, Hostname **`truenas`** (becomes the `instance` label), Update Every `15`,
   Send Names Instead Of IDs **on**, Matching Charts `*`. Save, enabled.
2. **Only if step 3 shows no `zfs_pool` series after a few minutes**: TrueNAS 25.04+ ships a
   Netdata config with many charts off. Restore them with the mapping's companion config (made
   for 25.04 — check its `[directories]` still match your version), from a TrueNAS shell as root:
   ```sh
   curl -fsSL -o /etc/netdata/netdata.conf \
     https://raw.githubusercontent.com/Supporterino/truenas-graphite-to-prometheus/v2.2.1/netdata.conf
   systemctl restart netdata
   ```
   **A TrueNAS update overwrites `/etc/netdata/netdata.conf`** — if you needed step 2, repeat it
   after every update (`TruenasPoolStateMissing` reminds you 6 h later). If that gets old: an
   API-based TrueNAS exporter (read-only API key) is the alternative — see "Open".
3. Check: `curl -s http://192.168.178.25:9108/metrics | grep '^zfs_pool'` shows one series per pool
   and state.

### Grafana dashboards

The repo provisions dashboards from grafana.com only when they select their datasource by
variable (`formulas/grafana` README); these all use import-time `${DS_…}` inputs, so import them
by hand (Dashboards → New → Import, datasource `Prometheus`):

- Proxmox: grafana.com **10347** "Proxmox via Prometheus".
- FRITZ!Box: `misc/grafana/fritz-exporter-overview.json` from the fritz_exporter repo at the
  pinned tag (built for the 4.x labels; grafana.com 13983 predates them).
- TrueNAS: the JSON in `dashboards/` of truenas-graphite-to-prometheus v2.2.1 (matches the mapping).

## Backup

None: all three containers are stateless (the mapping file is downloaded, everything else comes
from pillar), Salt rebuilds them completely. Hence no entry in `pillar/backup.sls`. No web UI,
so no homepage item either (the hosts themselves are on homepage already).

## Open

- TrueNAS via Graphite has no SMART health and depends on Netdata's chart set, which TrueNAS
  changes between releases. Exporters that read pool/vdev state and SMART results from the
  TrueNAS JSON-RPC API exist (e.g. katbyte/truenas-exporter, scottrus/truenas-scale-exporter,
  USA-RedDragon/truenas-exporter) but were all weeks old with a single maintainer (2026-11) —
  revisit once one has a track record; it would need a read-only API key in OpenBao.
- Plain HTTP between Prometheus and the exporters, TR-064 without TLS (LAN only).

## Updating

Image tags are Renovate-tracked (`map.jinja`). The mapping is pinned by URL + sha256 — to bump:
new release tag in `mapping_source`, `curl -sL <url> | sha256sum` into `mapping_sha256`, and
check the alert metric names (`zfs_pool`, `disk_temperature`) still exist in it.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - podman
  - infra-exporters
```

## Pillar

See `pillar.example.sls`; real values in `pillar/infra-exporters.sls`.
