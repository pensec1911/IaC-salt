# Real data goes in pillar/alertmanager.sls, referenced from pillar/top.sls.

alertmanager:
  # Optional — overrides for formulas/alertmanager/map.jinja defaults.
  lookup:
    tag: v0.34.1
    host_port: 9093
    config_dir: /opt/alertmanager/config
    data_dir: /opt/alertmanager/data
    # Must match the image's internal user ("nobody"), same as prometheus.
    uid: 65534
    gid: 65534

  # Rendered 1:1 into alertmanager.yml (upstream schema:
  # https://prometheus.io/docs/alerting/latest/configuration/). Replaces the
  # default (a "null" receiver that drops everything) wholesale. Secrets in
  # receivers via sdb, never literal — e.g. ntfy via the webhook receiver:
  config:
    route:
      receiver: ntfy
      group_by: [alertname, instance]
      repeat_interval: 12h
    receivers:
      - name: ntfy
        webhook_configs:
          - url: {{ salt['sdb.get']('sdb://osvault/homelab/data/alertmanager/ntfy?url') | yaml_encode }}
