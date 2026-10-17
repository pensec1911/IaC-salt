# Optional overrides for formulas/cadvisor/map.jinja. Nothing is required.
cadvisor:
  lookup:
    tag: v0.60.6
    # Not 8080 — taken by qBittorrent on arrstack.
    host_port: 8088
    # How often container stats are collected. Lower = more CPU.
    housekeeping_interval: 30s
