# Optional overrides for formulas/salt-minion/map.jinja. Nothing is
# required — the defaults run a drift check every hour on every minion.
salt-minion:
  lookup:
    drift_check:
      # False removes the schedule, the script and the metrics file.
      enabled: True
      # Self-repair: on drift, apply for real (then re-check). Only where a
      # re-apply is harmless — not on hosts whose containers restart a stack.
      enforce: False
      interval_minutes: 60
      splay_seconds: 300
      timeout_seconds: 900
      script: /usr/local/sbin/salt-drift-check
      textfile_dir: /var/lib/prometheus/node-exporter
      metrics_file: salt_drift.prom
      salt_call: /usr/bin/salt-call
      python: /usr/bin/python3
