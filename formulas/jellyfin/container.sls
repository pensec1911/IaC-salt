{% from "jellyfin/map.jinja" import jellyfin with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - jellyfin.config

{#- Media is bound read-only: Jellyfin only reads the library (metadata and
   artwork live in config_dir), and the arrstack is the only thing that
   should be writing to the share. LinuxServer image: PUID/PGID = media,
   mapped 1:1 in its user namespace; see map.jinja podman. #}
{%- set env = {'PUID': jellyfin.puid, 'PGID': jellyfin.pgid, 'TZ': jellyfin.timezone} %}
{%- if jellyfin.published_server_url %}
{%-   do env.update({'JELLYFIN_PublishedServerUrl': jellyfin.published_server_url}) %}
{%- endif %}
{%- set spec = {
    'name': jellyfin.container_name,
    'image': jellyfin.image,
    'tag': jellyfin.tag,
    'keep_uids': [jellyfin.puid],
    'keep_gids': [jellyfin.pgid],
    'ports': [jellyfin.http_port ~ ':8096'],
    'env': env,
    'volumes': [
        jellyfin.config_dir ~ ':/config:rw',
        jellyfin.cache_dir ~ ':/cache:rw',
        jellyfin.media_mount ~ ':/media:ro',
    ],
} %}
{%- do spec.update(jellyfin.podman) %}
{{ container('jellyfin-container', spec,
             require=[{'user': 'user-media'}, {'file': 'jellyfin-config-dir'},
                      {'file': 'jellyfin-cache-dir'}, {'mount': 'nfs-mount-media'}]) }}
