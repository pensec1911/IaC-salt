authentik:
  lookup:
    domain: home.example.com
    external_host: https://auth.home.example.com
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?secret_key') | yaml_encode }}
    pg_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?pg_password') | yaml_encode }}
    # One per OAuth2 provider blueprint (worker env HOMELAB_OIDC_<APP>_SECRET),
    # each an sdb.get of authentik/oidc-<app> client_secret like the above:
    # oidc_secrets:
    #   grafana: <sdb.get ...>
