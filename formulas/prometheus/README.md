# prometheus formula

Runs [prom/prometheus](https://hub.docker.com/r/prom/prometheus) as a Docker container. Depends
on the `docker` formula (installs the engine) — this formula only handles the container and its
config.

## What it manages

- `prometheus.config` — creates `config_dir`/`data_dir` and renders `prometheus.yml` from
  `files/prometheus.yml.j2` (pillar-driven `scrape_configs`; defaults to scraping only itself if
  unset).
- `prometheus.container` — runs the container via `docker_container.running`, bind-mounting both
  dirs. Restarts automatically when the rendered config changes (`watch`).

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
