{#- formulas/netbox on forgejo. All three secrets live in OpenBao
   netbox/app (formulas/netbox README "OpenBao"). #}
{%- from 'edge-routes.jinja' import urls %}
{%- set oidc = urls['auth'] ~ '/application/o/netbox' %}
netbox:
  lookup:
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?secret_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?db_password') | yaml_encode }}
    api_token_pepper: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?api_token_pepper') | yaml_encode }}
    # Behind Caddy (https) Django sees plain http from the proxy, so the
    # browser's https Origin has to be trusted explicitly for logins/forms.
    config:
      CSRF_TRUSTED_ORIGINS: {{ urls['netbox'] }}
      # Login via Authentik (OIDC provider "netbox", formulas/authentik):
      # "Log in with Authentik" button; a user is created on the first login
      # (not superuser — grant that once in the admin UI or with manage.py,
      # README). The local login form stays.
      # Only the backend — REMOTE_AUTH_ENABLED would turn on header-based
      # login (Remote-User), which nothing here needs.
      REMOTE_AUTH_BACKEND: social_core.backends.open_id_connect.OpenIdConnectAuth
    extra_secrets:
      oidc_client_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-netbox?client_secret') | yaml_encode }}
    extra_config: |
      # Without trailing slash: social-core appends /.well-known/... itself.
      SOCIAL_AUTH_OIDC_OIDC_ENDPOINT = '{{ oidc }}'
      SOCIAL_AUTH_OIDC_KEY = 'netbox'
      with open('/run/secrets/oidc_client_secret') as _f:
          SOCIAL_AUTH_OIDC_SECRET = _f.read().strip()  # secret-scan: allow (read from the secret file)
      SOCIAL_AUTH_BACKEND_ATTRS = {'oidc': ('Authentik', 'login')}
      LOGOUT_REDIRECT_URL = '{{ oidc }}/end-session/'
