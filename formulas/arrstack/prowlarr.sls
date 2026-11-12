{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.gluetun

{#- LinuxServer image in gluetun's network namespace (map.jinja attach,
   lsio_podman). PUID/PGID = media, mapped 1:1 in its user namespace. #}
{%- set spec = {
    'name': arrstack.prowlarr.container_name,
    'image': arrstack.prowlarr.image,
    'tag': arrstack.prowlarr.tag,
    'keep_uids': [arrstack.puid],
    'keep_gids': [arrstack.pgid],
    'env': {'PUID': arrstack.puid, 'PGID': arrstack.pgid, 'TZ': arrstack.timezone},
    'volumes': [arrstack.config_base ~ '/prowlarr:/config:rw'],
} %}
{%- do spec.update(arrstack.attach) %}
{%- do spec.update(arrstack.lsio_podman) %}
{{ container('prowlarr-container', spec, require=[{'user': 'user-media'}, {'file': 'arrstack-prowlarr-config-dir'}]) }}
