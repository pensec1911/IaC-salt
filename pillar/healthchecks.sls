{%- from 'features.jinja' import features %}
{%- from 'edge-routes.jinja' import edge %}
users:
  accounts:
    # Pinned uid/gid — the container runs as it (Podman User=, mapped 1:1).
    # Must match healthchecks:lookup:uid/gid below.
    - name: healthchecks
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/healthchecks
      uid: 975
      gid: 975

{#- Dead-man's switch for jobs (formulas/healthchecks): every job pings its
   check after each run, a missing ping is the alert (-> ntfy
   alerts-critical, integration set up in the UI, README "Manual steps").
   Who pings (slug = <job>-<minion>, via formulas/healthchecks-ping):
     drift-check-*   formulas/salt-minion hourly drift check, every minion
     backup-*        formulas/backup nightly run (pillar/top.sls backup list)
     restore-test-*  formulas/backup weekly restore test
     alertmanager-watchdog  Alertmanager's always-firing Watchdog
                     (pillar/prometheus.sls + pillar/alertmanager.sls)
   The minion lists below mirror salt/top.sls and pillar/top.sls — a new
   minion goes here too. Schedules/grace follow the job's timer: backup
   02:00 + 10 min delay + 45 min timeout; restore test Sun 04:00 + 30 min +
   60 min; drift check hourly + 5 min splay + up to 15 min run. #}
{%- set all_minions = ['salt-master', 'homepage', 'monitoring', 'arrstack', 'jellyfin', 'forgejo', 'gateway', 'edge', 'cloud-edge', 'docs'] %}
{%- set backup_minions = ['arrstack', 'jellyfin', 'monitoring', 'forgejo', 'gateway', 'edge', 'cloud-edge', 'salt-master', 'docs'] %}
{%- if features.wazuh %}
{%-   do all_minions.append('wazuh') %}
{%-   do backup_minions.append('wazuh') %}
{%- endif %}
healthchecks:
  lookup:
    uid: 975
    gid: 975
    site_root: "http://192.168.178.24:8000"
    # Also behind Caddy (https://healthchecks.<edge domain>); keep the two
    # defaults. Caddy sets X-Forwarded-Proto, so Django knows the request
    # was https and the browser's https Origin passes the CSRF check.
    allowed_hosts: [localhost, 127.0.0.1, healthchecks.{{ edge.domain }}]
    env:
      SECURE_PROXY_SSL_HEADER: "HTTP_X_FORWARDED_PROTO,https"
      # Login = the Authentik forward-auth login in front (route `auth:
      # forward`): Caddy copies X-Authentik-Email from Authentik's answer,
      # Healthchecks logs in the user with that e-mail (creates one if new).
      # Replaces the password login entirely — README "Login".
      REMOTE_USER_HEADER: HTTP_X_AUTHENTIK_EMAIL
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/app?secret_key') | yaml_encode }}
    # Optional: created in the UI after the first login (README).
    api_key: {{ (salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/project?api_key') or '') | yaml_encode }}
    checks:
      - slug: alertmanager-watchdog
        name: Alertmanager Watchdog
        tags: monitoring
        desc: Prometheus -> Alertmanager pipeline; pinged every ~2 min by the always-firing Watchdog alert.
        timeout: 300
        grace: 300
{%- for m in all_minions %}
      - slug: drift-check-{{ m }}
        name: Drift check {{ m }}
        tags: salt {{ m }}
        desc: formulas/salt-minion hourly drift check (and self-repair) on {{ m }}.
        timeout: 3600
        grace: 1800
{%- endfor %}
      - slug: openbao-snapshot-salt-master
        name: OpenBao snapshot
        tags: backup salt-master
        desc: formulas/openbao-snapshot nightly Raft snapshot of OpenBao, pulled by salt-master.
        schedule: "30 1 * * *"
        tz: Europe/Berlin
        grace: 3600
{%- for m in backup_minions %}
      - slug: backup-{{ m }}
        name: Backup {{ m }}
        tags: backup {{ m }}
        desc: formulas/backup nightly restic run on {{ m }}.
        schedule: "0 2 * * *"
        tz: Europe/Berlin
        grace: 3600
      - slug: restore-test-{{ m }}
        name: Restore test {{ m }}
        tags: backup {{ m }}
        desc: formulas/backup weekly restore test on {{ m }}.
        schedule: "0 4 * * 0"
        tz: Europe/Berlin
        grace: 7200
{%- endfor %}
