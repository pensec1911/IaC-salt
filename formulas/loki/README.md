# loki formula

Runs [Grafana Loki](https://github.com/grafana/loki) (`grafana/loki`) as a Docker container:
single binary, filesystem storage, the log store behind Grafana's Explore. Logs are shipped by
`formulas/alloy` on the docker hosts. Depends on the `docker` formula.

## What it manages

- `loki.config` — `config.yaml` in `config_dir` and `data_dir` (default `/opt/loki/{config,data}`,
  data owned by 65534).
  - tsdb index, schema v13, starting at `schema_from` (a fixed date; never edit it — a future
    schema change appends a new period).
  - Retention `retention_period` (default 720h = 30 days), enforced by the compactor.
  - No auth (`auth_enabled: false`): single tenant, LAN only, like Prometheus.
- `loki.container` — the container on `host_port` (default 3100), running as 65534:65534.
  Restarts when the config changes.
- `loki.mine` — Salt Mine entry `loki` (`network.ip_addrs` on `eth0`), pushed via `mine.update`
  and announced with `homelab/mine/updated` when the conf file changes — same as cadvisor.
  `formulas/alloy` builds its push URL from it.

No web UI — logs are read in Grafana (datasource `Loki` in `pillar/grafana.sls`), Explore →
`{host="arrstack", container="sonarr"}` or `{host="jellyfin", job="journal", unit="docker.service"}`.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - docker
  - loki
  - alloy
```

## Pillar

None required. See `pillar.example.sls`.
