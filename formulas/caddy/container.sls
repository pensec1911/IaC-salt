{% from "caddy/map.jinja" import caddy with context %}
{% from "podman/macros.jinja" import container, network with context %}

include:
  - caddy.config
  - caddy.image

{{ network('caddy-network', caddy.network) }}

{#- Runs as the caddy account (mapped 1:1); it writes only to /data and
   /config, so the default read-only root fits. 8443/8080 inside, so no
   capability for :443/:80. Porkbun keys via the 0600 secret env file. #}
{%- set spec = {
    'name': caddy.container_name,
    'image': caddy.built_image,
    'tag': caddy.ref_tag,
    'user': caddy.uid ~ ':' ~ caddy.gid,
    'keep_uids': [caddy.uid],
    'keep_gids': [caddy.gid],
    'network': caddy.network ~ '.network',
    'ports': [
        caddy.https_port ~ ':8443/tcp',
        caddy.http_port ~ ':8080/tcp',
        caddy.metrics_port ~ ':' ~ caddy.metrics_port ~ '/tcp',
    ],
    'volumes': [
        caddy.config_dir ~ ':/etc/caddy:ro',
        caddy.data_dir ~ ':/data:rw',
        caddy.state_dir ~ ':/config:rw',
    ],
} %}
{%- do spec.update({'secret_env': {}}) %}
{%- do spec.secret_env.update({'PORKBUN_API_KEY': caddy.porkbun_api_key}) %}{#- secret-scan: allow (pillar value from OpenBao) #}
{%- do spec.secret_env.update({'PORKBUN_API_SECRET_KEY': caddy.porkbun_secret_api_key}) %}{#- secret-scan: allow (pillar value from OpenBao) #}
{%- do spec.update(caddy.podman) %}
{{ container('caddy-container', spec,
             require=[{'user': 'user-caddy'}, {'file': 'caddy-data-dir'},
                      {'file': 'caddy-state-dir'}, {'file': 'caddy-caddyfile'},
                      {'cmd': 'caddy-network-daemon-reload'}],
             watch=[{'file': 'caddy-caddyfile'}]) }}
