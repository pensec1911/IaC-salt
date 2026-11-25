tailscale:
  lookup:
    login_server: https://hs.example.com
    auth_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/headscale/gateway?auth_key') | yaml_encode }}
    advertise_routes:
      - 192.168.178.0/24
    advertise_tags:
      - tag:gateway
