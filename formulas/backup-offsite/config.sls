{% from "backup-offsite/map.jinja" import offsite with context %}

{#- Every secret must be set and resolved (an unresolved sdb reference
   reaches here as the URI) — else fail instead of a timer that fails
   every night or, worse, an offsite repo with a guessable password. #}
{%- set required = [offsite.password, offsite.access_key_id, offsite.secret_access_key, offsite.source_password]
                  + (offsite.source_passwords.values() | list) %}
{%- set check = namespace(ok=True) %}
{%- if not (offsite.repository.startswith('s3:') and offsite.region) %}
{%-   set check.ok = False %}
{%- endif %}
{%- for s in required %}
{%-   if not (s is string and s and not s.startswith('sdb://')) %}
{%-     set check.ok = False %}
{%-   endif %}
{%- endfor %}
{%- set ok = check.ok %}

backup-offsite-config-valid:
{%- if ok %}
  test.succeed_without_changes:
    - name: backup_offsite:lookup is complete
{%- else %}
  test.fail_without_changes:
    - name: "backup_offsite:lookup: repository, region and every password/key must be set and resolved (pillar/backup-offsite.sls, OpenBao restic/offsite)"
{%- endif %}

backup-offsite-config-dir:
  file.directory:
    - name: {{ offsite.config_dir }}
    - user: root
    - group: root
    - mode: '0700'

backup-offsite-sources-dir:
  file.directory:
    - name: {{ offsite.config_dir }}/sources
    - user: root
    - group: root
    - mode: '0700'
    - clean: True
    - require:
      - file: backup-offsite-config-dir

{#- Root-only files, never in state output. #}
backup-offsite-password:
  file.managed:
    - name: {{ offsite.config_dir }}/password
    - contents: {{ offsite.password | yaml_encode }}
    - mode: '0600'
    - show_changes: False
    - require:
      - file: backup-offsite-config-dir
      - test: backup-offsite-config-valid

{#- sources/default + sources/<minion> for the overrides; the script picks
   sources/<repo dir> if present, else sources/default. clean: True on the
   directory drops a removed override. #}
{%- for name, value in [('default', offsite.source_password)] + (offsite.source_passwords | dictsort) %}
backup-offsite-source-{{ name }}:
  file.managed:
    - name: {{ offsite.config_dir }}/sources/{{ name }}
    - contents: {{ value | yaml_encode }}
    - mode: '0600'
    - makedirs: True
    - dir_mode: '0700'
    - show_changes: False
    - require:
      - file: backup-offsite-config-dir
      - test: backup-offsite-config-valid
    - require_in:
      - file: backup-offsite-sources-dir
{%- endfor %}

{#- Read by the unit and by hand for a restore (README "Restore"):
   `set -a; . /etc/restic-offsite/env; set +a`. Holds the S3 secret. #}
backup-offsite-env:
  file.managed:
    - name: {{ offsite.config_dir }}/env
    - contents: |
        # Managed by Salt (formulas/backup-offsite) — do not edit.
        # Repo of one minion: $RESTIC_OFFSITE_BASE/<minion>
        RESTIC_OFFSITE_BASE={{ offsite.repository }}
        RESTIC_PASSWORD_FILE={{ offsite.config_dir }}/password
        RESTIC_CACHE_DIR={{ offsite.cache_dir }}
        AWS_DEFAULT_REGION={{ offsite.region }}
        AWS_ACCESS_KEY_ID={{ offsite.access_key_id }}
        AWS_SECRET_ACCESS_KEY={{ offsite.secret_access_key }}
    - mode: '0600'
    - show_changes: False
    - require:
      - file: backup-offsite-config-dir
      - test: backup-offsite-config-valid

backup-offsite-script:
  file.managed:
    - name: {{ offsite.script }}
    - source: salt://backup-offsite/files/restic-offsite.py.j2
    - template: jinja
    - mode: '0750'
    - require:
      # restic package, and the share it copies from
      - sls: backup
      - sls: node-exporter
