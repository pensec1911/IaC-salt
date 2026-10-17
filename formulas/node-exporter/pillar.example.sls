# Optional overrides for formulas/node-exporter/map.jinja. Nothing is
# required — the package's defaults (port 9100, default collectors) work as-is.
node-exporter:
  lookup:
    pkg: prometheus-node-exporter
    service: prometheus-node-exporter
    # Off by default: Recommends pulls in prometheus-node-exporter-collectors
    # (smartmontools, extra timers) — no use on VMs without real disks.
    install_recommends: False
