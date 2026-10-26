# alertmanager formula

Runs [prom/alertmanager](https://hub.docker.com/r/prom/alertmanager) as a Docker container —
receives firing alerts from Prometheus and routes them to notification receivers. Depends on the
`docker` formula. The alert *rules* live in Prometheus (`prometheus:rule_groups`); Prometheus is
pointed here via `prometheus:alerting`.

## What it manages

- `alertmanager.config` — `config_dir`/`data_dir` (numeric-owned `65534`, the image's own user —
  same reasoning as `formulas/prometheus`) and `alertmanager.yml`, rendered 1:1 from the
  `alertmanager:config` pillar dict (mode `0640`, diff hidden: receivers may hold secrets).
- `alertmanager.container` — the container, restarted when the config changes.

Besides Prometheus, Wazuh posts its manager alerts here directly (`WazuhAlert`,
`WazuhVulnerability`, label `source=wazuh` — formulas/wazuh README "Alerts to Alertmanager").

Default config (no pillar) has only a `null` receiver: alerts are visible in the UI
(`:9093`) and in Grafana, but nothing is sent anywhere.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - docker
  - prometheus
  - alertmanager
```

## Pillar

See `pillar.example.sls`. Real values in `pillar/alertmanager.sls`. Receiver credentials/URLs
must come from OpenBao (`sdb.get … | yaml_encode`), see `.claude/docs/secrets.md`.
