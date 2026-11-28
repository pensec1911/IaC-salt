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
    # each needs its secret (OpenBao authentik/oidc-<slug>), the same secret
    # in the app's own pillar. One list for both, so they can't drift.
{%- set oidc_apps = [
    {'slug': 'grafana', 'name': 'Grafana', 'route': 'grafana', 'callback': '/login/generic_oauth'},
    {'slug': 'forgejo', 'name': 'Forgejo', 'route': 'git', 'callback': '/user/oauth2/authentik/callback'},
    {'slug': 'netbox', 'name': 'NetBox', 'route': 'netbox', 'callback': '/oauth/complete/oidc/'},
    {'slug': 'paperless', 'name': 'Paperless', 'route': 'docs', 'callback': '/accounts/oidc/authentik/login/callback/'},
    {'slug': 'patchmon', 'name': 'PatchMon', 'route': 'patchmon', 'callback': '/api/v1/auth/oidc/callback', 'verified_email': True},
] %}
    oidc_apps:
{%- for a in oidc_apps %}
      - slug: {{ a.slug }}
        name: {{ a.name }}
        launch_url: {{ urls[a.route] }}
        redirect_uris: ['{{ urls[a.route] ~ a.callback }}']
        verified_email: {{ a.get('verified_email', False) }}
{%- endfor %}
    oidc_secrets:
{%- for a in oidc_apps %}
      {{ a.slug }}: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-' ~ a.slug ~ '?client_secret') | yaml_encode }}
{%- endfor %}
