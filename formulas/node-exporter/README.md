# node-exporter formula

Installs Prometheus' [node_exporter](https://github.com/prometheus/node_exporter) from Debian's
own `prometheus-node-exporter` package and keeps the service running. Host metrics (CPU, RAM,
disk, network, filesystems incl. NFS mounts) on `:9100/metrics`.

A package rather than a container because it goes on **every** minion — `salt-master` and
`wazuh` have no Docker. The package creates its own `prometheus` system user, so nothing comes
from the `users` formula.

## What it manages

- `node-exporter.install` — the package, without Recommends (see `pillar.example.sls`).
- `node-exporter.service` — `prometheus-node-exporter`, enabled and running.

Listen address/collector flags stay the package's defaults. To change them, patch `ARGS` in
`/etc/default/prometheus-node-exporter` with `file.blockreplace`/`file.replace`, don't replace
the file.

## Usage

Every minion, right after `wazuh-agent`:

```yaml
# salt/top.sls
'some-minion':
  - users
  - wazuh-agent
  - node-exporter
```

Then add the host as a target of the `node` job in `pillar/prometheus.sls`.

## Pillar

None required. See `pillar.example.sls`.
