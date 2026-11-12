{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.config

{#- gluetun owns the network namespace every other container in this
   formula attaches to (network_mode: container:<this>) — so every LAN-
   reachable port has to be published HERE, not on the app containers,
   which can't publish ports of their own once they share gluetun's stack.
   FIREWALL_INPUT_PORTS is the other half: gluetun's own firewall drops
   inbound connections by default even to ports Podman published, unless
   explicitly allowed here. This pair is what makes "webUIs reachable on
   the LAN, everything else only via the VPN" actually work. #}
{#- Leak guard (see map.jinja, uplink_interface): one DROP per tunnel address,
   inserted ahead of gluetun's own rules. gluetun runs /iptables/post-rules.txt
   after setting up its firewall. Only for WireGuard — OpenVPN's tunnel
   address isn't known in advance. #}
{%- set tunnel_ips = [] %}
{%- if arrstack.gluetun.vpn_type == 'wireguard' %}
{%-   for addr in arrstack.gluetun.wireguard_addresses.split(',') if addr.strip() and ':' not in addr %}
{%-     do tunnel_ips.append(addr.strip().split('/')[0]) %}
{%-   endfor %}
{%- endif %}

arrstack-gluetun-post-rules:
  file.managed:
    - name: {{ arrstack.config_base }}/gluetun/iptables/post-rules.txt
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - contents: |
        # Managed by Salt (formulas/arrstack/gluetun.sls) — do not edit.
        {%- for ip in tunnel_ips %}
        iptables -I OUTPUT 1 -o {{ arrstack.gluetun.uplink_interface }} -s {{ ip }} -j DROP
        {%- endfor %}
    - require:
      - file: arrstack-gluetun-config-dir

{%- if arrstack.gluetun.port_forwarding %}

{#- Port forwarding hooks: the provider assigns a random forwarded port
   (and may change it on reconnect), so gluetun pushes it into qBittorrent
   via its WebUI API every time it changes, binding qBittorrent to the VPN
   interface while it's at it. Scripts instead of inline commands so the
   JSON quoting doesn't have to survive YAML + container env + gluetun's own
   command parsing. Requires qBittorrent's "Bypass authentication for
   clients on localhost" — see README "Port forwarding". #}
{%- set qbt_api = 'http://127.0.0.1:' ~ arrstack.qbittorrent.webui_port ~ '/api/v2/app/setPreferences' %}

# Called as: qbittorrent-port-up.sh <forwarded port> <vpn interface>
arrstack-gluetun-pf-up-script:
  file.managed:
    - name: {{ arrstack.config_base }}/gluetun/qbittorrent-port-up.sh
    - user: root
    - group: root
    - mode: '0755'
    - contents: |
        #!/bin/sh
        # Managed by Salt (formulas/arrstack/gluetun.sls) — do not edit.
        exec wget -O- -nv --retry-connrefused \
          --post-data "json={\"listen_port\":$1,\"current_network_interface\":\"$2\",\"random_port\":false,\"upnp\":false}" \
          {{ qbt_api }}
    - require:
      - file: arrstack-gluetun-config-dir

arrstack-gluetun-pf-down-script:
  file.managed:
    - name: {{ arrstack.config_base }}/gluetun/qbittorrent-port-down.sh
    - user: root
    - group: root
    - mode: '0755'
    - contents: |
        #!/bin/sh
        # Managed by Salt (formulas/arrstack/gluetun.sls) — do not edit.
        exec wget -O- -nv --retry-connrefused \
          --post-data "json={\"listen_port\":0,\"current_network_interface\":\"lo\"}" \
          {{ qbt_api }}
    - require:
      - file: arrstack-gluetun-config-dir
{%- endif %}

{#- Salt's files (post-rules, hook scripts) stay root-owned and are bound
   read-only; gluetun's own state (servers.json, …) goes to data/, which
   belongs to the container (:U — root inside, a sub-UID on the host).
   The WireGuard key goes through the 0600 secret env file, not the unit. #}
{%- set fw_ports = [arrstack.qbittorrent.webui_port, arrstack.sonarr.port, arrstack.radarr.port, arrstack.prowlarr.port, arrstack.bazarr.port, arrstack.slskd.webui_port] %}
{%- set env = {
    'VPN_SERVICE_PROVIDER': arrstack.gluetun.vpn_service_provider,
    'VPN_TYPE': arrstack.gluetun.vpn_type,
    'WIREGUARD_ADDRESSES': arrstack.gluetun.wireguard_addresses,
    'FIREWALL_INPUT_PORTS': fw_ports | map('string') | join(','),
} %}
{%- if arrstack.gluetun.server_countries %}
{%-   do env.update({'SERVER_COUNTRIES': arrstack.gluetun.server_countries}) %}
{%- endif %}
{%- set ports = [] %}
{%- for port in fw_ports %}{% do ports.append(port ~ ':' ~ port) %}{% endfor %}
{%- set volumes = [
    arrstack.config_base ~ '/gluetun/data:/gluetun:U',
    arrstack.config_base ~ '/gluetun/iptables:/iptables:ro',
] %}
{%- if arrstack.gluetun.port_forwarding %}
{#- {{PORT}}/{{VPN_INTERFACE}} are gluetun's placeholders, not Jinja. #}
{%-   do env.update({
        'VPN_PORT_FORWARDING': 'on',
        'PORT_FORWARD_ONLY': 'on',
        'VPN_PORT_FORWARDING_UP_COMMAND': '/bin/sh /scripts/qbittorrent-port-up.sh {{PORT}} {{VPN_INTERFACE}}',
        'VPN_PORT_FORWARDING_DOWN_COMMAND': '/bin/sh /scripts/qbittorrent-port-down.sh',
      }) %}
{%-   do volumes.append(arrstack.config_base ~ '/gluetun/qbittorrent-port-up.sh:/scripts/qbittorrent-port-up.sh:ro') %}
{%-   do volumes.append(arrstack.config_base ~ '/gluetun/qbittorrent-port-down.sh:/scripts/qbittorrent-port-down.sh:ro') %}
{%- endif %}
{%- set spec = {
    'name': arrstack.gluetun.container_name,
    'image': arrstack.gluetun.image,
    'tag': arrstack.gluetun.tag,
    'cap_add': arrstack.gluetun.cap_add,
    'devices': ['/dev/net/tun:/dev/net/tun'],
    'tmpfs': arrstack.gluetun.tmpfs,
    'ports': ports,
    'volumes': volumes,
    'env': env,
} %}
{%- do spec.update({'secret_env': {}}) %}
{%- do spec.secret_env.update({'WIREGUARD_PRIVATE_KEY': arrstack.gluetun.wireguard_private_key}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.update(arrstack.gluetun.podman) %}
{%- set req = [{'file': 'arrstack-gluetun-data-dir'}, {'file': 'arrstack-gluetun-post-rules'}] %}
{%- if arrstack.gluetun.port_forwarding %}
{%-   do req.extend([{'file': 'arrstack-gluetun-pf-up-script'}, {'file': 'arrstack-gluetun-pf-down-script'}]) %}
{%- endif %}
{#- watch: gluetun only reads post-rules.txt when it sets up its firewall. #}
{{ container('gluetun-container', spec, require=req,
             watch=[{'file': 'arrstack-gluetun-post-rules'}]) }}
