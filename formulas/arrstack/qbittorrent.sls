{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.gluetun

{#- LinuxServer image in gluetun's network namespace (map.jinja attach,
   lsio_podman). PUID/PGID = media, mapped 1:1 in its user namespace. #}
{%- set spec = {
    'name': arrstack.qbittorrent.container_name,
    'image': arrstack.qbittorrent.image,
    'tag': arrstack.qbittorrent.tag,
    'keep_uids': [arrstack.puid],
    'keep_gids': [arrstack.pgid],
    'env': {'PUID': arrstack.puid, 'PGID': arrstack.pgid, 'TZ': arrstack.timezone, 'WEBUI_PORT': arrstack.qbittorrent.webui_port},
    'volumes': [
        arrstack.config_base ~ '/qbittorrent:/config:rw',
        arrstack.media_mount ~ ':/media:rw',
        arrstack.qbittorrent.incomplete_dir ~ ':' ~ arrstack.qbittorrent.incomplete_container_path ~ ':rw',
    ],
} %}
{%- do spec.update(arrstack.attach) %}
{%- do spec.update(arrstack.lsio_podman) %}
{{ container('qbittorrent-container', spec, require=[{'user': 'user-media'}, {'file': 'arrstack-qbittorrent-config-dir'},
                  {'file': 'arrstack-qbittorrent-incomplete-dir'}, {'mount': 'nfs-mount-media'}]) }}
