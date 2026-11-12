{% from "loki/map.jinja" import loki with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - loki.config

{#- uid/gid mapped 1:1: data_dir stays owned by them on the host. #}
{%- set spec = {
    'name': loki.container_name,
    'image': loki.image,
    'tag': loki.tag,
    'user': loki.uid ~ ':' ~ loki.gid,
    'keep_uids': [loki.uid],
    'keep_gids': [loki.gid],
    'ports': [loki.host_port ~ ':3100'],
    'volumes': [
        loki.config_dir ~ ':/etc/loki:ro',
        loki.data_dir ~ ':/loki:rw',
    ],
    'command': ['-config.file=/etc/loki/config.yaml'],
} %}
{%- do spec.update(loki.podman) %}
{{ container('loki-container', spec,
             require=[{'file': 'loki-data-dir'}, {'file': 'loki-config'}],
             watch=[{'file': 'loki-config'}]) }}
