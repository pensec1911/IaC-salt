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
