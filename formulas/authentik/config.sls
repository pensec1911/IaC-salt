{% from "authentik/map.jinja" import authentik with context %}

{#- A blank or unresolved secret would start Authentik with a guessable key
   or an empty DB password — fail instead (an unresolved sdb reference
   reaches here as the URI). domain/external_host: the blueprints need them. #}
{%- set secrets = {} %}
{%- do secrets.update({'secret_key': authentik.secret_key}) %}
{%- do secrets.update({'pg_password': authentik.pg_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- set bad = [] %}
{%- for name, value in secrets | dictsort %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}
{%- for app, value in authentik.oidc_secrets | dictsort %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append('oidc_secrets:' ~ app) %}{% endif %}{#- secret-scan: allow (key name) #}
{%- endfor %}
{%- for key in ['domain', 'external_host'] %}
{%-   if not authentik[key] %}{% do bad.append(key) %}{% endif %}
{%- endfor %}

authentik-config-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "authentik:lookup empty or unresolved: {{ bad | join(', ') }} — secrets in OpenBao authentik/app (README)"
{%- else %}
  test.succeed_without_changes:
    - name: authentik:lookup is complete
{%- endif %}

authentik-base-dir:
  file.directory:
    - name: {{ authentik.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Owner left to the containers (:U, container.sls): only create. #}
{%- for name in ['data', 'certs', 'postgres'] %}

authentik-{{ name }}-dir:
  file.directory:
    - name: {{ authentik[name ~ '_dir'] }}
    - require:
      - file: authentik-base-dir
{%- endfor %}

authentik-dump-dir:
  file.directory:
    - name: {{ authentik.dump_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: authentik-base-dir

{#- Files bound one by one, 0444: the containers' users are sub-UIDs on the
   host. The 0700 dir keeps host users out. #}
authentik-secrets-dir:
  file.directory:
    - name: {{ authentik.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: authentik-base-dir
{%- for name, value in secrets | dictsort %}

authentik-secret-{{ name }}:
  file.managed:
    - name: {{ authentik.secrets_dir }}/{{ name }}
    {#- trim: `bao kv put x=-` stores stdin's trailing newline; postgres
       strips it from POSTGRES_PASSWORD_FILE, Authentik's file:// may not. #}
    - contents: {{ value | trim | yaml_encode }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: authentik-secrets-dir
      - test: authentik-config-valid
{%- endfor %}

{#- Root-owned, world-readable (no secrets — those come in via !Env),
   mounted read-only into the worker. clean: a blueprint dropped from the
   formula disappears (its objects stay in Authentik until removed there). #}
authentik-blueprints-dir:
  file.recurse:
    - name: {{ authentik.blueprints_dir }}
    - source: salt://authentik/files/blueprints
    - template: jinja
    - user: root
    - group: root
    - dir_mode: '0755'
    - file_mode: '0644'
    - clean: True
    - require:
      - file: authentik-base-dir
      - test: authentik-config-valid
