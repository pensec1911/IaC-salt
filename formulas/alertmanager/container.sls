{% from "alertmanager/map.jinja" import alertmanager with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - alertmanager.config

{#- uid/gid mapped 1:1: config and data dirs stay owned by them on the host. #}
{%- set spec = {
    'name': alertmanager.container_name,
    'image': alertmanager.image,
    'tag': alertmanager.tag,
    'user': alertmanager.uid ~ ':' ~ alertmanager.gid,
    'keep_uids': [alertmanager.uid],
    'keep_gids': [alertmanager.gid],
    'ports': [alertmanager.host_port ~ ':9093'],
    'volumes': [
        alertmanager.config_dir ~ ':/etc/alertmanager:ro',
        alertmanager.data_dir ~ ':/alertmanager:rw',
    ],
    'command': [
        '--config.file=/etc/alertmanager/alertmanager.yml',
        '--storage.path=/alertmanager',
    ],
} %}
{%- do spec.update(alertmanager.podman) %}
{{ container('alertmanager-container', spec,
             require=[{'file': 'alertmanager-data-dir'}, {'file': 'alertmanager.yml'}],
             watch=[{'file': 'alertmanager.yml'}]) }}
