{#- formulas/hosts on every LAN minion: the edge route names -> edge, so
   servers (homepage status dots, blackbox, OIDC back-channel later) resolve
   them like tailnet clients do. #}
{%- from 'edge-routes.jinja' import edge, routes %}
hosts:
  lookup:
    entries:
      - ip: {{ edge.ip }}
        names:
{%- for r in routes %}
          - {{ r.name }}.{{ edge.domain }}
{%- endfor %}
{#- Containers that call the names themselves and must see a new route at
   once: blackbox (name probes), homepage (status dots). #}
{%- set restart = {'monitoring': ['blackbox-exporter'], 'homepage': ['homepage']} %}
    restart_units: {{ restart.get(grains['id'], []) | json }}
