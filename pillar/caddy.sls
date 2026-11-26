{#- formulas/caddy on edge: https://<name>.home.<domain> for every route in
   pillar/edge-routes.jinja, one wildcard certificate via DNS-01 at Porkbun. #}
{%- from 'edge-routes.jinja' import edge, routes %}
users:
  accounts:
    # Pinned uid/gid — the container runs as it (Podman User=, mapped 1:1).
    # Must match caddy:lookup:uid/gid (map.jinja default 978).
    - name: caddy
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/caddy
      uid: 978
      gid: 978

caddy:
  lookup:
    domain: {{ edge.domain }}
    routes: {{ routes | json }}
    # Authentik's embedded outpost (formulas/authentik, same Podman network):
    # routes with auth: forward need a login first. Unconditional on purpose
    # — never derived from a secret lookup, so an OpenBao outage can't render
    # the routes open (formulas/caddy fails closed without it).
    forward_auth: http://authentik-server:9000
    porkbun_api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/porkbun/api?api_key') | yaml_encode }}
    porkbun_secret_api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/porkbun/api?secret_api_key') | yaml_encode }}
