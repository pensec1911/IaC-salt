{#- formulas/patchmon-agent on every minion. Per-minion credentials in
   OpenBao patchmon/agent/<minion id>; missing = not enrolled yet
   (formulas/patchmon-agent README "Enrol a minion"). #}
{%- set path = 'sdb://osvault/homelab/data/patchmon/agent/' ~ grains['id'] %}
patchmon-agent:
  lookup:
    server_url: http://192.168.178.29:3001
    api_id: {{ salt['sdb.get'](path ~ '?api_id') | yaml_encode }}
    api_key: {{ salt['sdb.get'](path ~ '?api_key') | yaml_encode }}
