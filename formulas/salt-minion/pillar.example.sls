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
      # Only repair inside this daily window (HH:MM, may wrap midnight);
      # report-only outside. Empty = always. Wider than interval + splay.
      enforce_window:
        start: ""
        end: ""
        timezone: UTC
      interval_minutes: 60
      splay_seconds: 300
      timeout_seconds: 900
      script: /usr/local/sbin/salt-drift-check
      textfile_dir: /var/lib/prometheus/node-exporter
      metrics_file: salt_drift.prom
      salt_call: /usr/bin/salt-call
      python: /usr/bin/python3
    beacons:
      # Service beacon -> master reactor starts a stopped service again
      # (only services on salt-master:lookup:beacon_restart_services).
      service:
        enabled: False
        services:
          - docker
        interval_seconds: 10
        # Down this long before the event fires. Must exceed the unit's
        # StartLimitIntervalSec (docker: 60 s) — see map.jinja.
        delay_seconds: 90
