{#- Scrape targets: minion -> IP (see .claude/docs/inventory.md). Every
   minion runs node-exporter; the docker hosts also run cadvisor. The
   `instance` label is set to the minion name so dashboards/alerts show
   "arrstack" instead of "192.168.178.22:9100". #}
{%- set node_hosts = {
    'salt-master': '192.168.178.28',
    'homepage': '192.168.178.23',
    'monitoring': '192.168.178.25',
    'arrstack': '192.168.178.22',
    'jellyfin': '192.168.178.24',
    'wazuh': '192.168.178.27',
} %}
{%- set cadvisor_hosts = ['homepage', 'monitoring', 'arrstack', 'jellyfin'] %}
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
            - {{ node_hosts['monitoring'] }}:9093
          labels:
            instance: monitoring
    - job_name: node
      static_configs:
{%- for name, ip in node_hosts | dictsort %}
        - targets:
            - {{ ip }}:9100
          labels:
            instance: {{ name }}
{%- endfor %}
    - job_name: cadvisor
      static_configs:
{%- for name in cadvisor_hosts %}
        - targets:
            - {{ node_hosts[name] }}:8088
          labels:
            instance: {{ name }}
{%- endfor %}

  alerting:
    - {{ node_hosts['monitoring'] }}:9093

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
        - alert: SaltDrift
          expr: salt_drift_states_pending > 0
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
