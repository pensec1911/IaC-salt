# Real data goes in pillar/healthchecks.sls, referenced from pillar/top.sls.
#
# Also requires (in the same pillar file — see formulas/users):
#   - users:accounts entry "healthchecks" with a PINNED uid/gid (must match
#     healthchecks:lookup:uid/gid below)

healthchecks:
  # Optional except site_root and secret_key — overrides for
  # formulas/healthchecks/map.jinja defaults.
  lookup:
    uid: 975
    gid: 975
    http_port: 8000
    site_root: "http://192.168.178.24:8000"
    allowed_hosts: []          # extra Host names besides site_root's and localhost
    env:                       # merged key by key over map.jinja's env
      SITE_NAME: Homelab Healthchecks
      GUNICORN_WORKERS: "2"
    # Secrets — OpenBao only, never literal (README "OpenBao").
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/app?secret_key') | yaml_encode }}
    # Optional: without it the checks below are not provisioned.
    api_key: {{ (salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/project?api_key') or '') | yaml_encode }}
    # Upserted via the Management API, unique by slug. Either timeout
    # (period, seconds) or schedule (cron) + tz; grace in seconds.
    checks:
      - slug: backup-somehost
        name: Backup somehost
        tags: backup somehost
        desc: nightly restic run
        schedule: "0 2 * * *"
        tz: Europe/Berlin
        grace: 3600
      - slug: drift-check-somehost
        name: Drift check somehost
        timeout: 3600
        grace: 1800
