# Optional overrides for formulas/node-exporter/map.jinja. Nothing is
# required — the package's defaults (port 9100, default collectors) work as-is.
node-exporter:
  lookup:
    pkg: prometheus-node-exporter
    service: prometheus-node-exporter
    # Off by default: Recommends pulls in prometheus-node-exporter-collectors
    # (smartmontools, extra timers) — no use on VMs without real disks.
    install_recommends: False
    # Salt Mine entry formulas/prometheus builds the `node` job from.
    mine:
      alias: node_exporter
      interface: eth0
      conf: /etc/salt/minion.d/mine-node-exporter.conf
