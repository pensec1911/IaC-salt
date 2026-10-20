# Optional overrides for formulas/loki/map.jinja. Nothing is required.
loki:
  lookup:
    tag: 3.7.8
    host_port: 3100
    config_dir: /opt/loki/config
    data_dir: /opt/loki/data
    # nobody via docker `user:` — the image's own user would be 10001.
    uid: 65534
    gid: 65534
    # Compactor deletes older chunks. 720h = 30 days.
    retention_period: 720h
    # Start of the tsdb/v13 schema period. Never change it once Loki has
    # data — see map.jinja.
    schema_from: "2026-10-20"
    log_level: warn
    # Salt Mine entry formulas/alloy reads the Loki address from.
    mine:
      alias: loki
      interface: eth0
      conf: /etc/salt/minion.d/mine-loki.conf
      event_tag: homelab/mine/updated
