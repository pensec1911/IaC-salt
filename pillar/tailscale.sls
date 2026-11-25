{#- formulas/tailscale on gateway: subnet router tailnet -> LAN. The key is a
   single-use, tagged Headscale pre-auth key (formulas/headscale README
   "Manual steps"); until it's in OpenBao gateway is installed, not joined. #}
tailscale:
  lookup:
    login_server: https://hs.ilpaa.xyz
    auth_key: {{ (salt['sdb.get']('sdb://osvault/homelab/data/headscale/gateway?auth_key') or '') | yaml_encode }}
    advertise_routes:
      - 192.168.178.0/24
    advertise_tags:
      - tag:gateway
    accept_dns: False
    snat_subnet_routes: True
