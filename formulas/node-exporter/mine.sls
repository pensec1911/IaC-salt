{% from "node-exporter/map.jinja" import node_exporter with context %}
{%- set mine = node_exporter.mine %}
{%- set functions = {mine.alias: {'mine_function': 'network.ip_addrs', 'interface': mine.interface}} %}

{#- Advertises this minion's IP under mine.alias; formulas/prometheus builds
   the `node` scrape job from it. The minion.d file is only read at
   salt-minion start, so the module.run pushes the entry right away instead
   of waiting for a restart. Salt deep-merges minion.d/*.conf, so the
   mine_functions of node-exporter and cadvisor coexist. #}
node-exporter-mine-conf:
  file.serialize:
    - name: {{ mine.conf }}
    - serializer: yaml
    - dataset:
        mine_functions: {{ functions | json }}

node-exporter-mine-update:
  module.run:
    - mine.update:
      - mine_functions: {{ functions | json }}
    - onchanges:
      - file: node-exporter-mine-conf
