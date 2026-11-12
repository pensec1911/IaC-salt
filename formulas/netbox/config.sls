{% from "netbox/map.jinja" import netbox with context %}

{#- A blank or unresolved secret would start NetBox with a guessable key or
   an empty DB password — fail instead (an unresolved sdb reference reaches
   here as the URI). #}
{#- name in /run/secrets -> value (pillar, i.e. OpenBao). #}
{%- set secrets = {} %}
{%- do secrets.update({'secret_key': netbox.secret_key}) %}
{%- do secrets.update({'db_password': netbox.db_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do secrets.update({'api_token_pepper_1': netbox.api_token_pepper}) %}
{%- set bad = [] %}
{%- for name, value in secrets | dictsort %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}

netbox-secrets-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "netbox:lookup secrets empty or unresolved: {{ bad | join(', ') }} — set them in OpenBao netbox/app (README)"
{%- else %}
  test.succeed_without_changes:
    - name: netbox:lookup secrets are set
{%- endif %}

netbox-base-dir:
  file.directory:
    - name: {{ netbox.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Owner left to the containers (:U, container.sls): only create. #}
{%- for name, dir in [('media', netbox.media_dir), ('postgres', netbox.postgres_dir), ('valkey', netbox.valkey_dir)] %}

netbox-{{ name }}-dir:
  file.directory:
    - name: {{ dir }}
    - require:
      - file: netbox-base-dir
{%- endfor %}

netbox-dump-dir:
  file.directory:
    - name: {{ netbox.dump_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: netbox-base-dir

{#- Files bound one by one, 0444: the containers' users are sub-UIDs on
   the host. The 0700 dir keeps host users out. #}
netbox-secrets-dir:
  file.directory:
    - name: {{ netbox.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: netbox-base-dir
{%- for name, value in secrets | dictsort %}

netbox-secret-{{ name }}:
  file.managed:
    - name: {{ netbox.secrets_dir }}/{{ name }}
    - contents: {{ value | yaml_encode }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: netbox-secrets-dir
      - test: netbox-secrets-valid
{%- endfor %}
