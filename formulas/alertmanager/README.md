# alertmanager formula

Runs [prom/alertmanager](https://hub.docker.com/r/prom/alertmanager) as a Podman container (Quadlet unit via `formulas/podman`) —
receives firing alerts from Prometheus and routes them to notification receivers. Depends on the
`podman` formula. The alert *rules* live in Prometheus (`prometheus:rule_groups`); Prometheus is
pointed here via `prometheus:alerting`.

## What it manages

- `alertmanager.config` — `config_dir`/`data_dir` (numeric-owned `65534`, the image's own user —
  same reasoning as `formulas/prometheus`) and `alertmanager.yml`, rendered 1:1 from the
  `alertmanager:config` pillar dict (mode `0640`, diff hidden: receivers may hold secrets).
- `alertmanager.container` — the container, restarted when the config changes.

Besides Prometheus, Wazuh posts its manager alerts here directly (`WazuhAlert`,
`WazuhVulnerability`, label `source=wazuh` — formulas/wazuh README "Alerts to Alertmanager").

Default config (no pillar) has only a `null` receiver: alerts are visible in the UI
(`:9093`) and in Grafana, but nothing is sent anywhere. `pillar/alertmanager.sls` adds push
notifications via ntfy on jellyfin (`formulas/ntfy`): topic `alerts-critical` (priority high)
and `alerts-warning` (everything else), grouped by `alertname`, rendered by ntfy's built-in
`?template=alertmanager`. Those receivers exist only while the token `ntfy/alertmanager` resolves
from OpenBao; without it the config falls back to `null` instead of failing.

Dead-man's switch: an always-firing `Watchdog` alert (`pillar/prometheus.sls`, `vector(1)`,
`severity: none`) is routed first and only to a webhook that pings Healthchecks on jellyfin
(`formulas/healthchecks`, check `alertmanager-watchdog`) every ~2 min; if the pings stop,
Healthchecks alerts via ntfy. Rule, route and receiver exist only while the Healthchecks ping key
(`healthchecks/project`) resolves. `/homelab-status` hides it from its firing list.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - podman
  - prometheus
  - alertmanager
```

## Pillar

See `pillar.example.sls`. Real values in `pillar/alertmanager.sls`. Receiver credentials/URLs
must come from OpenBao (`sdb.get … | yaml_encode`), see `.claude/docs/secrets.md`.
