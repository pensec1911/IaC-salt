{% from "ntfy/map.jinja" import ntfy with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - ntfy.config

{#- uid/gid mapped 1:1: data_dir stays owned by them on the host, and the
   group can read the root-owned server.yml. Everything ntfy writes is in
   /var/lib/ntfy, so the default read-only root fits. #}
{%- set spec = {
    'name': ntfy.container_name,
    'image': ntfy.image,
    'tag': ntfy.tag,
    'user': ntfy.uid ~ ':' ~ ntfy.gid,
    'keep_uids': [ntfy.uid],
    'keep_gids': [ntfy.gid],
    'ports': [ntfy.http_port ~ ':8080'],
    'volumes': [
        ntfy.config_dir ~ ':/etc/ntfy:ro',
        ntfy.data_dir ~ ':/var/lib/ntfy:rw',
    ],
    'command': ['serve', '--config', '/etc/ntfy/server.yml'],
} %}
{%- do spec.update(ntfy.podman) %}
{{ container('ntfy-container', spec,
             require=[{'user': 'user-ntfy'}, {'file': 'ntfy-data-dir'}, {'file': 'ntfy-server.yml'}],
             watch=[{'file': 'ntfy-server.yml'}]) }}
