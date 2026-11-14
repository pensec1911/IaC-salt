{% from "infra-exporters/map.jinja" import infra_exporters with context %}
{% from "podman/macros.jinja" import container with context %}
{%- set c = infra_exporters.truenas %}
{%- if c.enabled %}

include:
  - infra-exporters.config

{#- Pinned release + sha256, so a changed upstream file fails the state
   instead of silently renaming series. #}
infra-exporters-graphite-mapping:
  file.managed:
    - name: {{ infra_exporters.config_dir }}/graphite_mapping.conf
    - source: {{ c.mapping_source }}
    - source_hash: sha256={{ c.mapping_sha256 }}
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: infra-exporters-config-dir

{%- set spec = {
    'name': c.container_name,
    'image': c.image,
    'tag': c.tag,
    'ports': [
        c.host_port ~ ':' ~ c.container_port,
        c.graphite_port ~ ':9109/tcp',
        c.graphite_port ~ ':9109/udp',
    ],
    'volumes': [infra_exporters.config_dir ~ '/graphite_mapping.conf:/etc/graphite_mapping.conf:ro'],
    'command': [
        '--graphite.mapping-config=/etc/graphite_mapping.conf',
        '--graphite.mapping-strict-match',
        '--graphite.sample-expiry=' ~ c.sample_expiry,
        '--web.listen-address=:' ~ c.container_port,
    ],
} %}
{%- do spec.update(c.podman) %}
{{ container('infra-exporters-truenas-container', spec,
             require=[{'file': 'infra-exporters-graphite-mapping'}],
             watch=[{'file': 'infra-exporters-graphite-mapping'}]) }}
{%- endif %}
