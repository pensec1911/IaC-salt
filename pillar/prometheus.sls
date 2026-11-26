{#- node and cadvisor targets come from the Salt Mine (formulas/node-exporter,
   formulas/cadvisor publish each minion's IP; formulas/prometheus expands
   `mine:` jobs into one target per minion, `instance` = minion name). Only
   monitoring's own address is still listed here, for Alertmanager. #}
{%- set monitoring_ip = '192.168.178.25' %}
{%- from 'edge-routes.jinja' import edge, routes %}
{#- Watchdog only while Alertmanager has somewhere to send it (the
   Healthchecks ping key, same guard as pillar/alertmanager.sls) — otherwise
   it would just sit firing in the UI. #}
{%- set hc_ping_key = salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/project?ping_key') or '' %}
{%- set watchdog = hc_ping_key is string and hc_ping_key | length > 0 and not hc_ping_key.startswith('sdb://') %}
{#- Proxmox / FRITZ!Box exporters (formulas/infra-exporters) only run once
   their secret is in OpenBao — same checks as pillar/infra-exporters.sls;
   their jobs and rules follow, so nothing changes before that. #}
{%- set pve_token = salt['sdb.get']('sdb://osvault/homelab/data/proxmox/exporter?token_value') or '' %}
{%- set pve = pve_token is string and pve_token | length > 0 and not pve_token.startswith('sdb://') %}
{%- set fritz_password = salt['sdb.get']('sdb://osvault/homelab/data/fritzbox/exporter?password') or '' %}
{%- set fritzbox = fritz_password is string and fritz_password | length > 0 and not fritz_password.startswith('sdb://') %}
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
      # cAdvisor runs in raw-cgroup mode (formulas/cadvisor): a container
      # is only its cgroup id. name = the Quadlet unit = container name,
      # set on the container's own cgroup (libpod-payload-*), not on the
      # unit's or on other services' cgroups.
      metric_relabel_configs:
        - source_labels: [id]
          regex: '/system\.slice/([^/]+)\.service/libpod-payload-[0-9a-f]+'
          target_label: name
          replacement: '$1'
    # Every web UI with a status dot on homepage (pillar/homepage.sls —
    # monitoring gets it via pillar/top.sls), probed via blackbox-exporter.
    - job_name: blackbox
      probe:
        module: http_up
        exporter: {{ monitoring_ip }}:9115
        homepage: True
      # No web UI, so not on homepage: Headscale's public health endpoint
      # (cert expiry via CertificateExpiringSoon).
      static_configs:
        - targets:
            - https://hs.ilpaa.xyz/health
          labels:
            instance: headscale
            group: Infrastructure
    # The apps behind Caddy, probed on their upstream directly: with the
    # name probes above (homepage hrefs = https://<name>.home.<domain>),
    # a failure tells Caddy/certificate/DNS (name only) from the app (both).
    - job_name: blackbox-upstream
      probe:
        module: http_up
        exporter: {{ monitoring_ip }}:9115
      static_configs:
{%- for r in routes %}
        - targets:
            - {{ r.upstream }}
          labels:
            instance: {{ r.name }}
            group: upstream
{%- endfor %}
    # formulas/caddy on edge (metrics: requests, upstream health, certs).
    - job_name: caddy
      static_configs:
        - targets:
            - {{ edge.ip }}:9180
          labels:
            instance: edge
    # formulas/headscale on cloud-edge, through the WireGuard tunnel.
    - job_name: headscale
      static_configs:
        - targets:
            - 10.99.0.1:9090
          labels:
            instance: cloud-edge
{%- if pve %}
    # prometheus-pve-exporter (formulas/infra-exporters): one scrape per
    # node via ?target=. cluster=1 on every node, so the cluster view
    # (all nodes, storages, guests) survives one node being down — the
    # cluster series come three times (instance = the node asked), the
    # rules aggregate by id.
    - job_name: pve
      scrape_interval: 60s
      scrape_timeout: 30s
      metrics_path: /pve
      params:
        module: [default]
        cluster: ['1']
        node: ['1']
      static_configs:
        - targets: [192.168.178.11]
          labels:
            instance: pve01
        - targets: [192.168.178.12]
          labels:
            instance: pve02
        - targets: [192.168.178.13]
          labels:
            instance: pve03
      relabel_configs:
        - source_labels: [__address__]
          target_label: __param_target
        - target_label: __address__
          replacement: {{ monitoring_ip }}:9221
{%- endif %}
{%- if fritzbox %}
    # fritz_exporter (TR-064 is slow — 60s, as upstream suggests).
    - job_name: fritzbox
      scrape_interval: 60s
      scrape_timeout: 30s
      static_configs:
        - targets:
            - {{ monitoring_ip }}:9787
          labels:
            instance: fritzbox
{%- endif %}
    # graphite_exporter, fed by TrueNAS' Reporting → Exporters push. The
    # mapping sets job="truenas" and instance=<TrueNAS hostname> per series
    # (honor_labels keeps them; hostname is set to "truenas" there).
    - job_name: truenas
      honor_labels: true
      static_configs:
        - targets:
            - {{ monitoring_ip }}:9108
          labels:
            instance: truenas

  alerting:
    - {{ monitoring_ip }}:9093

  {#- raw blocks: the annotations use Prometheus' own {{ }} templating,
     which pillar's Jinja would otherwise try to render. #}
  rule_groups:
    - name: homelab
      rules:
{%- if watchdog %}
        {#- Always firing: proves Prometheus evaluates rules and Alertmanager
           delivers. Routed only to Healthchecks (pillar/alertmanager.sls),
           which alerts when the pings stop. #}
        - alert: Watchdog
          expr: vector(1)
          labels:
            severity: none
          annotations:
            summary: Always firing — dead-man's switch for the alerting pipeline (Healthchecks alertmanager-watchdog)
{%- endif %}
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
          expr: probe_success{job=~"blackbox|blackbox-upstream"} == 0
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
        {#- recyclarr_* from formulas/arrstack (daily TRaSH sync, ~07:00).
           A failed sync changes nothing in Sonarr/Radarr — the last synced
           profiles stay — so warning, and Stale only after 3 missed days. #}
        - alert: RecyclarrSyncFailed
          expr: recyclarr_sync_success == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"recyclarr sync on {{ $labels.instance }} failed — journalctl -u recyclarr-sync"{% endraw %}
        - alert: RecyclarrSyncStale
          expr: time() - recyclarr_last_success_timestamp_seconds > 3 * 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"{{ $labels.instance }} has no successful recyclarr sync for over 3 days"{% endraw %}
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
        {#- Only HTTPS probe targets have the metric. The self-signed ones
           (Proxmox, TrueNAS, OpenBao, Wazuh) are checked too — TLS isn't
           verified (blackbox http_up), but expiry still is; all run for
           ~1–10 years (2026-10-26), so no exclusions. #}
        - alert: CertificateExpiringSoon
          expr: probe_ssl_earliest_cert_expiry - time() < 14 * 86400
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"TLS certificate of {{ $labels.instance }} expires in {{ $value | humanizeDuration }}"{% endraw %}
        {#- os_* from formulas/unattended-upgrades (hourly + after boot).
           formulas/orch reboots pending minions nightly at 03:15 Berlin, ~20h
           after a morning u-u run (~06:00 UTC); 26h only fires when that
           night's run didn't do it (failed, minion skipped, timer off). #}
        - alert: RebootRequired
          expr: os_reboot_required == 1
          for: 26h
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
        {#- pve_* from prometheus-pve-exporter (job pve, only while its token
           is in OpenBao). Every node reports the whole cluster, so the
           rules take max by (id): one answering node is enough. All three
           down → TargetDown on job pve. #}
{%- if pve %}
        - alert: PveNodeDown
          expr: max by (id) (pve_up{job="pve", id=~"node/.+"}) == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"Proxmox {{ $labels.id }} is offline in the cluster"{% endraw %}
        - alert: PveNodeMemoryHigh
          expr: >-
            max by (id) (
              pve_memory_usage_bytes{job="pve", id=~"node/.+"}
              / pve_memory_size_bytes{job="pve", id=~"node/.+"}
            ) > 0.90
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Proxmox {{ $labels.id }} uses {{ $value | humanizePercentage }} of its RAM — rebalance VMs (.claude/docs/capacity.md)"{% endraw %}
        - alert: PveStorageAlmostFull
          expr: >-
            max by (id) (
              pve_disk_usage_bytes{job="pve", id=~"storage/.+"}
              / (pve_disk_size_bytes{job="pve", id=~"storage/.+"} > 0)
            ) > 0.90
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"Proxmox {{ $labels.id }} is {{ $value | humanizePercentage }} full"{% endraw %}
{%- endif %}
        {#- fritz_* from fritz_exporter (job fritzbox, only while its password
           is in OpenBao). phys link = DSL sync (or cable/fibre link); PPP
           only exists on a PPPoE line — absent series never fire. #}
{%- if fritzbox %}
        - alert: FritzboxUnreachable
          expr: fritz_device_reachable{job="fritzbox"} == 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"fritz_exporter can't reach {{ $labels.friendly_name }} — TR-064 on, user/password right? (formulas/infra-exporters README)"{% endraw %}
        - alert: FritzboxWanLinkDown
          expr: fritz_wan_phys_link_status{job="fritzbox"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"{{ $labels.friendly_name }}: WAN link down (DSL sync lost)"{% endraw %}
        - alert: FritzboxInternetDisconnected
          expr: >-
            fritz_ppp_connection_state{job="fritzbox"} == 0
            unless on(serial) fritz_wan_phys_link_status{job="fritzbox"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"{{ $labels.friendly_name }}: line is up but the PPP session is not connected"{% endraw %}
{%- endif %}
        {#- zfs_pool / disk_temperature: Netdata charts via TrueNAS' Graphite
           push and the Supporterino mapping (formulas/infra-exporters).
           zfs_pool is 1 for the pool's current state, 0 for the others.
           graphite_exporter drops series 5m after the last push, so a
           stopped push or a missing Netdata chart shows as Missing. #}
        - alert: TruenasPoolNotOnline
          expr: zfs_pool{job="truenas", state!="online"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: {% raw %}"TrueNAS pool {{ $labels.pool }} is {{ $labels.state }}"{% endraw %}
        - alert: TruenasPoolStateMissing
          expr: absent(zfs_pool{job="truenas"})
          for: 6h
          labels:
            severity: warning
          annotations:
            summary: "No ZFS pool state from TrueNAS — Reporting → Exporters set up, Netdata config applied? (formulas/infra-exporters README)"
        - alert: TruenasDiskHot
          expr: disk_temperature{job="truenas"} > 55
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: {% raw %}"TrueNAS disk {{ $labels.serial }} at {{ $value }}°C"{% endraw %}
