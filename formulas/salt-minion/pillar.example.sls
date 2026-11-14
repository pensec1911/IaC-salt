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
    version:
      # Exact Salt version for every host; empty = unmanaged (Tofu's
      # "3008.*" pin stays). Upgrade: orch.salt-upgrade (formulas/orch).
      target: "3008.3"
      # The salt-master's host: exempt from the cap below.
      master_id: salt-master
      # Cap for every other host. Set it in pillar from salt['test.version']()
      # — pillar renders in the master, so that is the master's own version
      # (pillar/salt-minion-version.sls).
      master_running: ""
      packages: [salt-common, salt-minion, salt-master, salt-api, salt-syndic, salt-ssh, salt-cloud]
      pin_file: /etc/apt/preferences.d/salt-pin-1001
      pin_package: "salt-*"            # apt preference Package: line
      pin_priority: 1001
      upgrade:
        unit: salt-upgrade             # transient systemd unit running apt
        script: /usr/local/sbin/salt-upgrade
        delay_seconds: 15              # after the state returns
        idle_seconds: 900              # wait for running jobs, then give up
        proc_dir: /var/cache/salt/minion/proc
        onedir_dir: /opt/saltstack/salt
        apt_get: /usr/bin/apt-get
        lock_timeout: 300              # s, dpkg lock (unattended-upgrades)
