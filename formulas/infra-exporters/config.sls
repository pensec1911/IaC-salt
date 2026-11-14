{% from "infra-exporters/map.jinja" import infra_exporters with context %}

{#- An enabled exporter with a blank or unresolved credential would only
   log in failures against the device — fail instead (an unresolved sdb
   reference reaches here as the URI). pillar/infra-exporters.sls enables
   them only once the secret resolves, so this is the backstop. #}
{%- set secrets = {} %}
{%- if infra_exporters.pve.enabled %}
{%-   do secrets.update({'pve.token_value': infra_exporters.pve.token_value}) %}{#- secret-scan: allow (variable, not a value) #}
{%- endif %}
{%- if infra_exporters.fritzbox.enabled %}
{%-   do secrets.update({'fritzbox.password': infra_exporters.fritzbox.password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- endif %}
{%- set bad = [] %}
{%- for name, value in secrets | dictsort %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}

infra-exporters-secrets-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "infra-exporters:lookup secrets empty or unresolved: {{ bad | join(', ') }} — set them in OpenBao (formulas/infra-exporters README)"
{%- else %}
  test.succeed_without_changes:
    - name: infra-exporters:lookup secrets are set
{%- endif %}

infra-exporters-config-dir:
  file.directory:
    - name: {{ infra_exporters.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
