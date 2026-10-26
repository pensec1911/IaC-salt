{#- node and cadvisor targets come from the Salt Mine (formulas/node-exporter,
   formulas/cadvisor publish each minion's IP; formulas/prometheus expands
   `mine:` jobs into one target per minion, `instance` = minion name). Only
   monitoring's own address is still listed here, for Alertmanager. #}
{%- set monitoring_ip = '192.168.178.25' %}
prometheus:
  scrape_configs:
    - job_name: prometheus
      static_configs:
        - targets:
            - localhost:9090
          labels:
            instance: monitoring
    - job_name: alertmanager
      static_configs:
        - targets:
            - {{ monitoring_ip }}:9093
          labels:
            instance: monitoring
    - job_name: node
      mine:
        alias: node_exporter
        port: 9100
    - job_name: cadvisor
      mine:
        alias: cadvisor
        port: 8088
    # Every web UI with a status dot on homepage (pillar/homepage.sls —
    # monitoring gets it via pillar/top.sls), probed via blackbox-exporter.
    - job_name: blackbox
      probe:
        module: http_up
        exporter: {{ monitoring_ip }}:9115
        homepage: True

  alerting:
    - {{ monitoring_ip }}:9093

  {#- raw blocks: the annotations use Prometheus' own {{ }} templating,
     which pillar's Jinja would otherwise try to render. #}
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
        {#- A mine job that rendered no targets has no `up` series, so
           TargetDown can't fire for it — e.g. monitoring applied before
           any minion published its mine entry. #}
        - alert: ScrapeJobEmpty
          expr: absent(up{job="node"}) or absent(up{job="cadvisor"})
          for: 15m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"Scrape job {{ $labels.job }} has no targets — Salt Mine empty? Apply the exporter minions, then monitoring"{% endraw %}
        - alert: ProbeFailed
          expr: probe_success{job="blackbox"} == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} ({{ $labels.group }}) doesn't answer — {{ $labels.url }}"{% endraw %}
        - alert: DiskAlmostFull
          expr: >-
            node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}
            / node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs"} < 0.10
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.mountpoint }} on {{ $labels.instance }} has under 10% free"{% endraw %}
        - alert: MemoryLow
          expr: node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} has under 10% memory available"{% endraw %}
        - alert: CpuBusy
          expr: 1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.90
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} CPU over 90% for 30m"{% endraw %}
        {#- salt_drift_* come from formulas/salt-minion (hourly highstate dry
           run). The metric only changes once per run, so `for: 90m` means
           "still drifted at the next run" — a push that is applied within
           the hour never alerts. #}
        {#- Not while a windowed enforce minion (arrstack, jellyfin) waits
           for its night window: drift there is expected until the repair
           runs. Drift that survives the window fires during it (for: 90m
           inside the 3h window); failed repairs: SaltDriftRepairFailed. #}
        - alert: SaltDrift
          expr: >-
            salt_drift_states_pending > 0
            unless on(instance) (salt_drift_enforce == 1 and salt_drift_enforce_window_open == 0)
          for: 90m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} differs from git in {{ $value }} state(s) — run state.apply test=True"{% endraw %}
        - alert: SaltDriftCheckFailing
          expr: salt_drift_check_success == 0 or salt_drift_states_failed > 0
          for: 90m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Highstate dry run on {{ $labels.instance }} fails (render error, failing state or master unreachable)"{% endraw %}
        {#- Only on enforce minions (pillar/salt-minion-enforce.sls). The
           repair metrics carry over between runs, so only while the host is
           still drifted/failing — a later manual fix clears it. #}
        - alert: SaltDriftRepairFailed
          expr: >-
            salt_drift_repair_last_success == 0
            and on(instance) (salt_drift_states_pending > 0 or salt_drift_states_failed > 0)
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Self-repair state.apply on {{ $labels.instance }} had failed states — run state.apply by hand"{% endraw %}
        - alert: SaltDriftCheckStale
          expr: time() - salt_drift_last_run_timestamp_seconds > 3 * 3600
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Drift check on {{ $labels.instance }} has not run for over 3h"{% endraw %}
        {#- Stale needs the metric to exist once; this catches a minion whose
           node-exporter is up but that never wrote it (schedule missing). #}
        - alert: SaltDriftCheckMissing
          expr: up{job="node"} == 1 unless on(instance) salt_drift_last_run_timestamp_seconds
          for: 3h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} exposes no drift-check metrics — is salt-minion in its top.sls?"{% endraw %}
        {#- backup_* come from formulas/backup (nightly restic run, ~02:00).
           Both fire until the next successful night; last_success starts
           at 0, so Stale also catches a host that never succeeded. A host
           whose timer never ran has no metrics at all — check
           `systemctl list-timers restic-backup.timer` after adding one. #}
        - alert: BackupFailed
          expr: backup_success == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Backup on {{ $labels.instance }} failed — journalctl -u restic-backup"{% endraw %}
        - alert: BackupStale
          expr: time() - backup_last_success_timestamp_seconds > 36 * 3600
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} has no successful backup for over 36h"{% endraw %}
        {#- restore_test_* from formulas/backup (weekly restore test, Sunday
           ~04:00): repo sample readable, latest snapshot restores, SQLite
           files pass integrity_check. Stale after 8 days covers a missed
           week; last_success starts at 0 like the backup metric. #}
        - alert: RestoreTestFailed
          expr: restore_test_success == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Restore test on {{ $labels.instance }} failed — journalctl -u restic-restore-test"{% endraw %}
        - alert: RestoreTestStale
          expr: time() - restore_test_last_success_timestamp_seconds > 8 * 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} has no successful restore test for over 8 days"{% endraw %}
        {#- node_timex_* from node-exporter's timex collector; every minion
           syncs from the FRITZ!Box via formulas/ntp. #}
        - alert: ClockNotSynced
          expr: node_timex_sync_status == 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} clock is not NTP-synchronised — timedatectl timesync-status"{% endraw %}
        - alert: ClockOffset
          expr: abs(node_timex_offset_seconds) > 0.5
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} clock is {{ $value | humanizeDuration }} off its NTP source"{% endraw %}
        {#- os_* from formulas/unattended-upgrades (hourly + after boot).
           Reboots are manual; 12h lets a morning u-u run (~06:00 UTC) be
           rebooted the same evening before it alerts. #}
        - alert: RebootRequired
          expr: os_reboot_required == 1
          for: 12h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} needs a reboot after updates — cat /run/reboot-required.pkgs"{% endraw %}
        {#- u-u installs security updates daily; still pending after 48h
           means a failing run, a held/blacklisted package or a dependency
           u-u won't resolve. #}
        - alert: SecurityUpgradesPending
          expr: os_security_upgrades_pending > 0
          for: 48h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} has {{ $value }} security upgrade(s) pending for 2 days — unattended-upgrade --dry-run --debug"{% endraw %}
        - alert: UnattendedUpgradeStale
          expr: time() - os_unattended_upgrade_last_run_timestamp_seconds > 3 * 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"unattended-upgrades on {{ $labels.instance }} has not run for over 3 days — systemctl status apt-daily-upgrade"{% endraw %}
        {#- apt-daily (lists) runs at 06/18:00 + up to 12h random delay;
           without fresh lists u-u and the pending counts see nothing new. #}
        - alert: AptListsStale
          expr: time() - os_apt_lists_updated_timestamp_seconds > 3 * 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Package lists on {{ $labels.instance }} not updated for over 3 days — journalctl -u apt-daily"{% endraw %}
        - alert: PatchMetricsStale
          expr: >-
            os_patch_metrics_success == 0
            or time() - os_patch_metrics_last_run_timestamp_seconds > 3 * 3600
          for: 3h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Patch metrics on {{ $labels.instance }} failing or stale — journalctl -u os-patch-metrics"{% endraw %}
