{% from "patchmon-agent/map.jinja" import agent with context %}

{#- sha256-checked against the pin: a binary swapped by the server's
   auto-update (off — formulas/patchmon README) would be put back here. #}
patchmon-agent-binary:
  file.managed:
    - name: {{ agent.bin }}
    - source: {{ agent.url.format(version=agent.version) }}
    - source_hash: sha256={{ agent.sha256 }}
    - user: root
    - group: root
    - mode: '0755'
