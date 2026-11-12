{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.gluetun

{#- Subtitles for Sonarr/Radarr's libraries. Needs the media bind: it writes
   .srt files next to the video files. Talks to Sonarr/Radarr as
   http://localhost:<port> (shared network namespace). #}
{#- LinuxServer image in gluetun's network namespace (map.jinja attach,
   lsio_podman). PUID/PGID = media, mapped 1:1 in its user namespace. #}
{%- set spec = {
    'name': arrstack.bazarr.container_name,
    'image': arrstack.bazarr.image,
    'tag': arrstack.bazarr.tag,
    'keep_uids': [arrstack.puid],
    'keep_gids': [arrstack.pgid],
    'env': {'PUID': arrstack.puid, 'PGID': arrstack.pgid, 'TZ': arrstack.timezone},
    'volumes': [
        arrstack.config_base ~ '/bazarr:/config:rw',
        arrstack.media_mount ~ ':/media:rw',
    ],
} %}
{%- do spec.update(arrstack.attach) %}
{%- do spec.update(arrstack.lsio_podman) %}
{{ container('bazarr-container', spec, require=[{'user': 'user-media'}, {'file': 'arrstack-bazarr-config-dir'}, {'mount': 'nfs-mount-media'}]) }}
