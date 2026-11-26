{#- formulas/authentik on edge, behind Caddy at https://auth.<edge domain>.
   Secrets in OpenBao authentik/app (formulas/authentik README). #}
{%- from 'edge-routes.jinja' import edge, urls %}
authentik:
  lookup:
    domain: {{ edge.domain }}
    external_host: {{ urls['auth'] }}
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?secret_key') | yaml_encode }}
    pg_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?pg_password') | yaml_encode }}
    # Apps that log in against Authentik themselves (OIDC). client_id = slug;
    # each needs its secret below (OpenBao authentik/oidc-<slug>) and the
    # same secret in the app's own pillar.
    oidc_apps:
      - slug: grafana
        name: Grafana
        launch_url: {{ urls['grafana'] }}
        redirect_uris: ['{{ urls['grafana'] }}/login/generic_oauth']
      - slug: forgejo
        name: Forgejo
        launch_url: {{ urls['git'] }}
        redirect_uris: ['{{ urls['git'] }}/user/oauth2/authentik/callback']
      - slug: netbox
        name: NetBox
        launch_url: {{ urls['netbox'] }}
        redirect_uris: ['{{ urls['netbox'] }}/oauth/complete/oidc/']
    oidc_secrets:
{%- for slug in ['grafana', 'forgejo', 'netbox'] %}
      {{ slug }}: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-' ~ slug ~ '?client_secret') | yaml_encode }}
{%- endfor %}
