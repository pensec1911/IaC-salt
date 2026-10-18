# prometheus formula

Runs [prom/prometheus](https://hub.docker.com/r/prom/prometheus) as a Docker container. Depends
on the `docker` formula (installs the engine) — this formula only handles the container and its
config.

## What it manages

- `prometheus.config` — creates `config_dir`/`data_dir` and renders `prometheus.yml` from
  `files/prometheus.yml.j2` (pillar-driven `scrape_configs`; defaults to scraping only itself if
  unset; `alerting` → Alertmanager targets) and the rule file from `files/rules.yml.j2`
  (`rule_groups`, always present, empty if unset).
- `prometheus.container` — runs the container via `docker_container.running`, bind-mounting both
  dirs. Restarts automatically when the rendered config or rules change (`watch`).

No dedicated host user (`users` formula) is created for this. The official image already runs
internally as a fixed user, uid `65534` ("nobody") — creating a *second* system account pinned to
that same uid would collide with Debian's own pre-existing `nobody` account. Instead, `config_dir`
and `data_dir` are numeric-owned (`65534:65534`) directly, and the container's `user:` param is
set to match — no `/etc/passwd` entry needed for a bind mount to work.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - users
  - docker
  - prometheus
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/prometheus.sls`
(referenced from `pillar/top.sls`).

Nothing is required in practice — the defaults produce a working single-target Prometheus
scraping only itself. Add real scrape targets by setting `prometheus:scrape_configs` (this
**replaces** the default list wholesale, same as any other pillar list override in this repo — it
doesn't merge with the self-scrape default, so include a `prometheus` job entry yourself if you
still want it scraped).

Alert rules: `rule_groups` is rendered 1:1 (upstream rule-file schema). Annotation templates
(`{{ $labels.instance }}`) must be wrapped in `{% raw %}…{% endraw %}` in pillar, otherwise
pillar's own Jinja render tries to resolve them. Where notifications go is configured in
`formulas/alertmanager`, not here.

**Mine-backed jobs**: a job with `mine: {alias, port}` instead of (or in addition to)
`static_configs` gets one target `<ip>:<port>` per minion returned by
`mine.get('*', alias)`, labelled `instance: <minion id>`. The mine is read when this minion's
highstate renders `prometheus.yml` — a new minion appears after its own highstate (which
publishes the entry) plus one here; until then `monitoring`'s drift check shows
`prometheus.yml` as pending. A job whose mine is empty renders `static_configs: []`
(`ScrapeJobEmpty` alert in `pillar/prometheus.sls`).

On a fresh `monitoring` the first highstate misses monitoring's *own* targets (the template
renders before its node-exporter/cadvisor mine states run) — apply twice, or pre-publish with
`salt monitoring mine.send node_exporter mine_function=network.ip_addrs interface=eth0`
(same for `cadvisor`).

Targets in this repo set an `instance` label per host (the minion name) so dashboards and
alerts don't show bare `IP:port`.
