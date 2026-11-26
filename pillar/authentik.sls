{#- formulas/authentik on edge, behind Caddy at https://auth.<edge domain>.
   Secrets in OpenBao authentik/app (formulas/authentik README). #}
{%- from 'edge-routes.jinja' import edge, urls %}
authentik:
  lookup:
    domain: {{ edge.domain }}
    external_host: {{ urls['auth'] }}
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?secret_key') | yaml_encode }}
    pg_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/app?pg_password') | yaml_encode }}
