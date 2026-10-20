{% from "loki/map.jinja" import loki with context %}
{%- set mine = loki.mine %}
{%- set functions = {mine.alias: {'mine_function': 'network.ip_addrs', 'interface': mine.interface}} %}

{#- Advertises this minion's IP under mine.alias; formulas/alloy builds its
   Loki push URL from it. The minion.d file is only read at salt-minion
   start, so the module.run pushes the entry right away instead of waiting
   for a restart. Salt deep-merges minion.d/*.conf, so the mine_functions of
   node-exporter, cadvisor and loki coexist. #}
loki-mine-conf:
  file.serialize:
    - name: {{ mine.conf }}
    - serializer: yaml
    - dataset:
        mine_functions: {{ functions | json }}

loki-mine-update:
  module.run:
    - mine.update:
      - mine_functions: {{ functions | json }}
    - onchanges:
      - file: loki-mine-conf

{#- Tells the master the mine changed (new minion, new alias); its reactor
   re-applies the minions that read the mine (formulas/salt-master,
   mine_consumers). Not on every run — only when the conf file changed. #}
loki-mine-event:
  event.send:
    - name: {{ mine.event_tag }}
    - onchanges:
      - file: loki-mine-conf
    - require:
      - module: loki-mine-update
