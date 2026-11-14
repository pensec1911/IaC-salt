{% from "infra-exporters/map.jinja" import infra_exporters with context %}
{% from "podman/macros.jinja" import container with context %}
{%- set c = infra_exporters.fritzbox %}
{%- if c.enabled %}

include:
  - infra-exporters.config

{#- Single device, configured by env; the password goes into the 0600
   secret env file. FRITZ_PORT is the exporter's own listen port. #}
{%- set spec = {
    'name': c.container_name,
    'image': c.image,
    'tag': c.tag,
    'ports': [c.host_port ~ ':' ~ c.container_port],
    'env': {
        'FRITZ_NAME': c.name,
        'FRITZ_HOSTNAME': c.hostname,
        'FRITZ_USERNAME': c.username,
        'FRITZ_PORT': c.container_port,
    },
} %}
{%- do spec.update({'secret_env': {'FRITZ_PASSWORD': c.password}}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.update(c.podman) %}
{{ container('infra-exporters-fritzbox-container', spec,
             require=[{'test': 'infra-exporters-secrets-valid'}]) }}
{%- endif %}
