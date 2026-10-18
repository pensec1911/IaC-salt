# Real data for this minion goes in pillar/prometheus.sls, referenced from
# pillar/top.sls. This file just documents the schema.

prometheus:
  # Optional — overrides for formulas/prometheus/map.jinja defaults.
  # Nothing here is required in practice; the image ships working defaults.
  lookup:
    tag: v2.55.1
    host_port: 9090
    config_dir: /opt/prometheus/config
    data_dir: /opt/prometheus/data
    retention: 15d
    # File name of the rendered rule file inside config_dir.
    rules_file: rules.yml
    # uid/gid: must match the image's own internal user (65534, "nobody")
    # since no host OS account is created for this — see README.md.
    uid: 65534
    gid: 65534

  # Rendered into prometheus.yml. Defaults to scraping only itself
  # (localhost:9090) when unset — add real targets as this grows, e.g.:
  scrape_configs:
    - job_name: prometheus
      static_configs:
        - targets:
            - localhost:9090
    # Or let the Salt Mine supply the targets: one <ip>:<port> per minion
    # publishing `alias` (formulas/node-exporter / cadvisor), with
    # instance=<minion id>. Combinable with static_configs.
    # - job_name: node
    #   mine:
    #     alias: node_exporter
    #     port: 9100

  # Alertmanager(s) to send firing alerts to. Unset = no alerting section.
  alerting:
    - 192.168.178.X:9093

  # Rendered 1:1 as the `groups:` of the rule file (upstream schema). Empty
  # when unset. Wrap annotation templates in {% raw %}…{% endraw %} — pillar
  # is Jinja-rendered and would otherwise eat Prometheus' own {{ }}:
  rule_groups:
    - name: homelab
      rules:
        - alert: TargetDown
          expr: up == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"{{ $labels.job }} on {{ $labels.instance }} is down"{% endraw %}
