{% from "healthchecks/map.jinja" import healthchecks with context %}

{#- A blank or unresolved SECRET_KEY would let Django run with a known or empty
   signing key — fail instead (an unresolved sdb reference reaches here as
   the URI). site_root is required too: without it every ping URL in the UI
   points at localhost. #}
{%- set key = healthchecks.secret_key %}
{%- set bad = [] %}
{%- if not key or key.startswith('sdb://') %}{% do bad.append('secret_key') %}{% endif %}
{%- if not healthchecks.site_root %}{% do bad.append('site_root') %}{% endif %}

healthchecks-config-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "healthchecks:lookup empty or unresolved: {{ bad | join(', ') }} — secret_key from OpenBao healthchecks/app (README)"
{%- else %}
  test.succeed_without_changes:
    - name: healthchecks:lookup secret_key and site_root are set
{%- endif %}

healthchecks-base-dir:
  file.directory:
    - name: {{ healthchecks.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- hc.sqlite (checks, pings, users, integrations). #}
healthchecks-data-dir:
  file.directory:
    - name: {{ healthchecks.data_dir }}
    - user: {{ healthchecks.uid }}
    - group: {{ healthchecks.gid }}
    - mode: '0750'
    - require:
      - file: healthchecks-base-dir
      - user: user-healthchecks
