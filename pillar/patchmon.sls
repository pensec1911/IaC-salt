{#- formulas/patchmon on forgejo. Secrets in OpenBao patchmon/server
   (formulas/patchmon README "OpenBao"). #}
{%- from 'edge-routes.jinja' import urls %}
patchmon:
  lookup:
    # Comma list: the server also only accepts requests whose Host is one of
    # these — the name behind Caddy for browsers, the IP for the agents.
    cors_origin: "{{ urls['patchmon'] }},http://192.168.178.29:3001"
    jwt_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?jwt_secret') | yaml_encode }}
    session_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?session_secret') | yaml_encode }}
    ai_encryption_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?ai_encryption_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?db_password') | yaml_encode }}
    # Login via Authentik (OIDC provider "patchmon", pillar/authentik.sls
    # oidc_apps, verified_email: PatchMon links an existing account only by a
    # verified e-mail). Local login stays as break-glass (README "Login").
    oidc_client_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-patchmon?client_secret') | yaml_encode }}
    env:
      OIDC_ENABLED: "true"
      OIDC_ISSUER_URL: "{{ urls['auth'] }}/application/o/patchmon/"
      OIDC_CLIENT_ID: patchmon
      OIDC_REDIRECT_URI: "{{ urls['patchmon'] }}/api/v1/auth/oidc/callback"
      # Authentik has no "groups" scope; its profile scope carries the groups claim.
      OIDC_SCOPES: openid email profile
      OIDC_BUTTON_TEXT: Login with Authentik
      # Only "authentik Admins" may log in at all (Authentik policy binding).
      OIDC_SUPERADMIN_GROUP: authentik Admins
      OIDC_SYNC_ROLES: "true"
      OIDC_DEFAULT_ROLE: readonly
      OIDC_AUTO_CREATE_USERS: "false"
