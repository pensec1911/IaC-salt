{% from "patchmon/map.jinja" import patchmon with context %}

{#- A blank or unresolved secret would start PatchMon with guessable
   session/JWT keys — fail instead (an unresolved sdb reference reaches here
   as the URI). Names only, never values, in the message. #}
{%- set bad = [] %}
{%- for name in ['jwt_secret', 'session_secret', 'ai_encryption_key', 'db_password'] %}
{%-   set value = patchmon.get(name) or '' %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}

patchmon-secrets-valid:
{%- if bad or not patchmon.cors_origin %}
  test.fail_without_changes:
    - name: "patchmon:lookup incomplete: {{ (bad + ([] if patchmon.cors_origin else ['cors_origin'])) | join(', ') }} — secrets in OpenBao patchmon/server (README)"
{%- else %}
  test.succeed_without_changes:
    - name: patchmon:lookup secrets are set
{%- endif %}

patchmon-base-dir:
  file.directory:
    - name: {{ patchmon.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Owner/mode left to the entrypoints (they chown on start): only create. #}
{%- for name, dir in [('postgres', patchmon.postgres_dir), ('valkey', patchmon.valkey_dir)] %}

patchmon-{{ name }}-dir:
  file.directory:
    - name: {{ dir }}
    - require:
      - file: patchmon-base-dir
{%- endfor %}

patchmon-dump-dir:
  file.directory:
    - name: {{ patchmon.dump_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: patchmon-base-dir

patchmon-secrets-dir:
  file.directory:
    - name: {{ patchmon.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: patchmon-base-dir

{#- Read by the server via ENV_FILE. DATABASE_URL spelled out: the loader
   doesn't expand ${VAR}. -#}
{%- set db_url = 'postgresql://' ~ patchmon.db_user ~ ':' ~ (patchmon.db_password | urlencode) ~ '@' ~ patchmon.postgres_container_name ~ ':5432/' ~ patchmon.db_name %}

patchmon-env-file:
  file.managed:
    - name: {{ patchmon.secrets_dir }}/patchmon.env
    - contents: |
        # Managed by Salt (formulas/patchmon) — do not edit.
        JWT_SECRET={{ patchmon.jwt_secret }}
        SESSION_SECRET={{ patchmon.session_secret }}
        AI_ENCRYPTION_KEY={{ patchmon.ai_encryption_key }}
        POSTGRES_PASSWORD={{ patchmon.db_password }}
        DATABASE_URL={{ db_url }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False   # secrets — keep them out of state output / job cache
    - require:
      - file: patchmon-secrets-dir
      - test: patchmon-secrets-valid

patchmon-db-password-file:
  file.managed:
    - name: {{ patchmon.secrets_dir }}/db_password
    - contents: {{ patchmon.db_password | yaml_encode }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False
    - require:
      - file: patchmon-secrets-dir
      - test: patchmon-secrets-valid
