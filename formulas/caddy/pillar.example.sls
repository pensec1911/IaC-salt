users:
  accounts:
    - name: caddy
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/caddy
      uid: 978
      gid: 978

caddy:
  lookup:
    domain: home.example.com
    porkbun_api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/porkbun/api?api_key') | yaml_encode }}
    porkbun_secret_api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/porkbun/api?secret_api_key') | yaml_encode }}
    routes:
      - {name: grafana, upstream: 'http://192.168.178.25:3000', auth: oidc}
      - {name: sonarr, upstream: 'http://192.168.178.22:8989', auth: forward}
    # Step 6: Authentik's outpost; routes with auth: forward go through it.
    # forward_auth: http://authentik-server:9000
