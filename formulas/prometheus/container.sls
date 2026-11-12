{% from "prometheus/map.jinja" import prometheus with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - prometheus.config

{#- uid/gid mapped 1:1: config and data dirs stay owned by them on the host. #}
{%- set spec = {
    'name': prometheus.container_name,
    'image': prometheus.image,
    'tag': prometheus.tag,
    'user': prometheus.uid ~ ':' ~ prometheus.gid,
    'keep_uids': [prometheus.uid],
    'keep_gids': [prometheus.gid],
    'ports': [prometheus.host_port ~ ':9090'],
    'volumes': [
        prometheus.config_dir ~ ':/etc/prometheus:ro',
        prometheus.data_dir ~ ':/prometheus:rw',
    ],
    'command': [
        '--config.file=/etc/prometheus/prometheus.yml',
        '--storage.tsdb.path=/prometheus',
        '--storage.tsdb.retention.time=' ~ prometheus.retention,
    ],
} %}
{%- do spec.update(prometheus.podman) %}
{%- set files = [{'file': 'prometheus.yml'}, {'file': 'prometheus-rules'}] %}
{{ container('prometheus-container', spec,
             require=[{'file': 'prometheus-data-dir'}] + files, watch=files) }}
