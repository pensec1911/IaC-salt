{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

{#- Solves Cloudflare challenges for Prowlarr's indexers. Lives in gluetun's
   network namespace like everything else, so the challenge requests leave
   through the VPN too, and Prowlarr reaches it as http://localhost:<port>.
   Deliberately NOT in gluetun's port_bindings/FIREWALL_INPUT_PORTS: only
   Prowlarr talks to it, nothing on the LAN needs to.

   No PUID/PGID (not an LSIO image) and no config dir: it's stateless. #}
flaresolverr-container:
  docker_container.running:
    - name: {{ arrstack.flaresolverr.container_name }}
    - image: {{ arrstack.flaresolverr.image }}:{{ arrstack.flaresolverr.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - LOG_LEVEL={{ arrstack.flaresolverr.log_level }}
      - PORT={{ arrstack.flaresolverr.port }}
      - TZ={{ arrstack.timezone }}
    # watch, not just require: see sonarr.sls — when gluetun is recreated
    # its namespace is gone and this container would be left without one.
    - watch:
      - docker_container: gluetun-container
