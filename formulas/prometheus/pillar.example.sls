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
    # - job_name: node
    #   static_configs:
    #     - targets:
    #         - some-minion:9100
    #       labels:
    #         role: minion
