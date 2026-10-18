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
- `node-exporter.mine` — Salt Mine entry `node_exporter` (`network.ip_addrs` on `eth0`) in
  `/etc/salt/minion.d/mine-node-exporter.conf`, pushed once via `mine.update` when that file changes.
  `formulas/prometheus` builds its `node` scrape job from `mine.get('*', 'node_exporter')`, so a new
  minion with this formula gets scraped without editing `pillar/prometheus.sls`.

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

Prometheus picks the host up via the mine after this minion's highstate **and** the next
`state.apply` on `monitoring`.

## Pillar

None required. See `pillar.example.sls`.
