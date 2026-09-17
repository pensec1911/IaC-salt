{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.config

{#- gluetun owns the network namespace every other container in this
   formula attaches to (network_mode: container:<this>) — so every LAN-
   reachable port has to be published HERE, not on the app containers,
   which can't publish ports of their own once they share gluetun's stack.
   FIREWALL_INPUT_PORTS is the other half: gluetun's own firewall drops
   inbound connections by default even to ports docker published, unless
   explicitly allowed here. This pair is what makes "webUIs reachable on
   the LAN, everything else only via the VPN" actually work. #}
gluetun-container:
  docker_container.running:
    - name: {{ arrstack.gluetun.container_name }}
    - image: {{ arrstack.gluetun.image }}:{{ arrstack.gluetun.tag }}
    - restart_policy: unless-stopped
    - cap_add:
      - NET_ADMIN
    - devices:
      - /dev/net/tun:/dev/net/tun
    - binds:
      - {{ arrstack.config_base }}/gluetun:/gluetun:rw
    - port_bindings:
      - {{ arrstack.qbittorrent.webui_port }}:{{ arrstack.qbittorrent.webui_port }}/tcp
      - {{ arrstack.sonarr.port }}:{{ arrstack.sonarr.port }}/tcp
      - {{ arrstack.radarr.port }}:{{ arrstack.radarr.port }}/tcp
      - {{ arrstack.prowlarr.port }}:{{ arrstack.prowlarr.port }}/tcp
      - {{ arrstack.slskd.webui_port }}:{{ arrstack.slskd.webui_port }}/tcp
    - environment:
      - VPN_SERVICE_PROVIDER={{ arrstack.gluetun.vpn_service_provider }}
      - VPN_TYPE={{ arrstack.gluetun.vpn_type }}
      - WIREGUARD_PRIVATE_KEY={{ arrstack.gluetun.wireguard_private_key }}
      - WIREGUARD_ADDRESSES={{ arrstack.gluetun.wireguard_addresses }}
      {%- if arrstack.gluetun.server_countries %}
      - SERVER_COUNTRIES={{ arrstack.gluetun.server_countries }}
      {%- endif %}
      - FIREWALL_INPUT_PORTS={{ [arrstack.qbittorrent.webui_port, arrstack.sonarr.port, arrstack.radarr.port, arrstack.prowlarr.port, arrstack.slskd.webui_port] | map('string') | join(',') }}
    - require:
      - sls: docker
      - file: arrstack-gluetun-config-dir
