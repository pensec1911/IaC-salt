{% from "backup/map.jinja" import backup with context %}

backup-config-dir:
  file.directory:
    - name: {{ backup.config_dir }}
    - user: root
    - group: root
    - mode: '0700'

{#- A blank or unresolved password would init a repo nobody can rely on —
   fail instead (an unresolved sdb reference reaches here as the URI). #}
{%- set password_ok = backup.password and not backup.password.startswith('sdb://') %}

backup-password-valid:
{%- if password_ok %}
  test.succeed_without_changes:
    - name: backup:lookup:password is set
{%- else %}
  test.fail_without_changes:
    - name: "backup:lookup:password is empty or unresolved — set it in pillar (OpenBao restic/repo)"
{%- endif %}

backup-password-file:
  file.managed:
    - name: {{ backup.config_dir }}/password
    - contents: {{ backup.password | yaml_encode }}
    - user: root
    - group: root
    - mode: '0600'
    - show_changes: False   # it's a secret — keep it out of state output / job cache
    - require:
      - file: backup-config-dir
      - test: backup-password-valid

{#- Read by the unit (EnvironmentFile) and by hand for a restore:
   `set -a; . /etc/restic/env; set +a; restic snapshots`. #}
backup-env-file:
  file.managed:
    - name: {{ backup.config_dir }}/env
    - contents: |
        # Managed by Salt (formulas/backup) — do not edit.
        RESTIC_REPOSITORY={{ backup.repo_base }}/{{ grains['id'] }}
        RESTIC_PASSWORD_FILE={{ backup.config_dir }}/password
        RESTIC_CACHE_DIR={{ backup.cache_dir }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: backup-config-dir

backup-script:
  file.managed:
    - name: {{ backup.script }}
    - source: salt://backup/files/restic-backup.py.j2
    - template: jinja
    - mode: '0755'
    - require:
      - pkg: backup-packages
      - sls: node-exporter
