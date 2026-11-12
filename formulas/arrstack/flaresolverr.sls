{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.gluetun

{#- Solves Cloudflare challenges for Prowlarr's indexers. Lives in gluetun's
   network namespace like everything else, so the challenge requests leave
   through the VPN too, and Prowlarr reaches it as http://localhost:<port>.
   Deliberately NOT in gluetun's published ports/FIREWALL_INPUT_PORTS: only
   Prowlarr talks to it, nothing on the LAN needs to.

   No PUID/PGID (not an LSIO image; runs as its own image user) and no
   config dir: it's stateless. Writable root fs: Chromium's profile. #}
{%- set spec = {
    'name': arrstack.flaresolverr.container_name,
    'image': arrstack.flaresolverr.image,
    'tag': arrstack.flaresolverr.tag,
    'env': {
        'LOG_LEVEL': arrstack.flaresolverr.log_level,
        'PORT': arrstack.flaresolverr.port,
        'TZ': arrstack.timezone,
    },
} %}
{%- do spec.update(arrstack.attach) %}
{%- do spec.update(arrstack.flaresolverr.podman) %}
{{ container('flaresolverr-container', spec) }}
