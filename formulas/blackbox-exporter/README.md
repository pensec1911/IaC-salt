# blackbox-exporter formula

Runs [blackbox_exporter](https://github.com/prometheus/blackbox_exporter) (`prom/blackbox-exporter`)
as a Docker container: Prometheus asks it to probe a URL (`/probe?target=…&module=…`) and gets
`probe_success`, status code, latency, TLS expiry back. Depends on the `docker` formula.

cAdvisor only shows that a container runs; this shows that the app behind it answers.

## What it manages

- `blackbox-exporter.config` — `config.yml` in `config_dir` (default
  `/opt/blackbox-exporter/config`), its `modules:` from `map.jinja` / pillar.
- `blackbox-exporter.container` — the container on `host_port` (default 9115), running as
  65534:65534 (the image would run as root). Restarts when `config.yml` changes.

Default module `http_up`: follows redirects, accepts 200/204/**401/403** (login-protected UIs are
up), skips TLS verification (self-signed certs on Proxmox, TrueNAS, OpenBao, Wazuh), IPv4 only.

## Targets: the homepage list

The exporter itself knows no targets. `formulas/prometheus` has a `probe:` job option; with
`probe.homepage: True` it probes every item in `pillar/homepage.sls` that has a status dot
(`siteMonitor`, default = `href`; `siteMonitor: false` skips it), labelled `instance=<item name>`,
`group=<homepage group>`. Every web UI goes on homepage anyway (CLAUDE.md), so a new UI is probed
without touching anything here — after monitoring's next highstate (it self-repairs hourly).
For this, monitoring gets `homepage` in `pillar/top.sls` too (read-only data there).

`ProbeFailed` (`pillar/prometheus.sls`) fires when a probe fails for 5 min.

Try a probe by hand: `curl 'http://<monitoring>:9115/probe?module=http_up&target=http://192.168.178.24:8096'`.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - docker
  - blackbox-exporter
  - prometheus
```

## Pillar

None required. See `pillar.example.sls`.
