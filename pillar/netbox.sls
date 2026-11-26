{#- formulas/netbox on forgejo. All three secrets live in OpenBao
   netbox/app (formulas/netbox README "OpenBao"). #}
{%- from 'edge-routes.jinja' import urls %}
netbox:
  lookup:
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?secret_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?db_password') | yaml_encode }}
    api_token_pepper: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?api_token_pepper') | yaml_encode }}
    # Behind Caddy (https) Django sees plain http from the proxy, so the
    # browser's https Origin has to be trusted explicitly for logins/forms.
    config:
      CSRF_TRUSTED_ORIGINS: {{ urls['netbox'] }}
