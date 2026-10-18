# Optional overrides for formulas/cadvisor/map.jinja. Nothing is required.
cadvisor:
  lookup:
    tag: v0.60.6
    # Not 8080 — taken by qBittorrent on arrstack.
    host_port: 8088
    # How often container stats are collected. Lower = more CPU.
    housekeeping_interval: 30s
    # Salt Mine entry formulas/prometheus builds the `cadvisor` job from.
    mine:
      alias: cadvisor
      interface: eth0
      conf: /etc/salt/minion.d/mine-cadvisor.conf
      # Fired when the conf changes; formulas/salt-master's reactor listens.
      event_tag: homelab/mine/updated
