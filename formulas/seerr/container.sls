{% from "seerr/map.jinja" import seerr with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - seerr.config

{#- Default bridge network, not gluetun's namespace: Seerr only talks to
   TMDB and the LAN (Jellyfin, Sonarr, Radarr), nothing that needs the VPN.
   uid/gid mapped 1:1: config_dir stays owned by them on the host. #}
{%- set spec = {
    'name': seerr.container_name,
    'image': seerr.image,
    'tag': seerr.tag,
    'user': seerr.uid ~ ':' ~ seerr.gid,
    'keep_uids': [seerr.uid],
    'keep_gids': [seerr.gid],
    'ports': [seerr.http_port ~ ':5055'],
    'env': {'TZ': seerr.timezone},
    'volumes': [seerr.config_dir ~ ':/app/config:rw'],
} %}
{%- do spec.update(seerr.podman) %}
{{ container('seerr-container', spec,
             require=[{'user': 'user-seerr'}, {'file': 'seerr-config-dir'}]) }}
