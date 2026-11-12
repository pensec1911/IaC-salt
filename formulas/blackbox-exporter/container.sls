{% from "blackbox-exporter/map.jinja" import blackbox_exporter with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - blackbox-exporter.config

{#- Writes nothing, so no id mapping: nobody is a sub-UID on the host. #}
{%- set spec = {
    'name': blackbox_exporter.container_name,
    'image': blackbox_exporter.image,
    'tag': blackbox_exporter.tag,
    'user': blackbox_exporter.uid ~ ':' ~ blackbox_exporter.gid,
    'ports': [blackbox_exporter.host_port ~ ':9115'],
    'volumes': [blackbox_exporter.config_dir ~ ':/etc/blackbox_exporter:ro'],
    'command': ['--config.file=/etc/blackbox_exporter/config.yml'],
} %}
{%- do spec.update(blackbox_exporter.podman) %}
{{ container('blackbox-exporter-container', spec,
             require=[{'file': 'blackbox-exporter-config'}],
             watch=[{'file': 'blackbox-exporter-config'}]) }}
