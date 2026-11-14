{% from "infra-exporters/map.jinja" import infra_exporters with context %}
{% from "podman/macros.jinja" import container with context %}
{%- set c = infra_exporters.pve %}
{%- if c.enabled %}

include:
  - infra-exporters.config

{#- Config by env (the exporter reads PVE_* when PVE_USER is set); the
   token value goes into the 0600 secret env file. Listens on IPv4 only
   (default [::]:9221) — the bridge has no IPv6. #}
{%- set spec = {
    'name': c.container_name,
    'image': c.image,
    'tag': c.tag,
    'ports': [c.host_port ~ ':' ~ c.container_port],
    'env': {
        'PVE_USER': c.user,
        'PVE_TOKEN_NAME': c.token_name,
        'PVE_VERIFY_SSL': c.verify_ssl | string | lower,
    },
    'secret_env': {'PVE_TOKEN_VALUE': c.token_value},
    'command': ['--web.listen-address=0.0.0.0:' ~ c.container_port],
} %}
{%- do spec.update(c.podman) %}
{{ container('infra-exporters-pve-container', spec,
             require=[{'test': 'infra-exporters-secrets-valid'}]) }}
{%- endif %}
