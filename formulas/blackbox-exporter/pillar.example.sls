# Optional overrides for formulas/blackbox-exporter/map.jinja. Nothing is
# required — the probe targets are configured on the Prometheus side
# (prometheus:scrape_configs, a job with `probe:`), not here.
blackbox-exporter:
  lookup:
    tag: v0.29.0
    host_port: 9115
    config_dir: /opt/blackbox-exporter/config
    # The image runs as root otherwise; HTTP probes don't need it.
    uid: 65534
    gid: 65534
    # Upstream `modules:` schema, merged into the defaults (http_up).
    modules:
      http_up:
        http:
          valid_status_codes: [200, 204, 401, 403]
