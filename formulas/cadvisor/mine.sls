{% from "cadvisor/map.jinja" import cadvisor with context %}
{%- set mine = cadvisor.mine %}
{%- set functions = {mine.alias: {'mine_function': 'network.ip_addrs', 'interface': mine.interface}} %}

{#- Advertises this minion's IP under mine.alias; formulas/prometheus builds
   the `cadvisor` scrape job from it. The minion.d file is only read at
   salt-minion start, so the module.run pushes the entry right away instead
   of waiting for a restart. Salt deep-merges minion.d/*.conf, so the
   mine_functions of node-exporter and cadvisor coexist. #}
cadvisor-mine-conf:
  file.serialize:
    - name: {{ mine.conf }}
    - serializer: yaml
    - dataset:
        mine_functions: {{ functions | json }}

cadvisor-mine-update:
  module.run:
    - mine.update:
      - mine_functions: {{ functions | json }}
    - onchanges:
      - file: cadvisor-mine-conf

{#- Tells the master the mine changed (new minion, new alias); its reactor
   re-applies the minions that read the mine (formulas/salt-master,
   mine_consumers). Not on every run — only when the conf file changed. #}
cadvisor-mine-event:
  event.send:
    - name: {{ mine.event_tag }}
    - onchanges:
      - file: cadvisor-mine-conf
    - require:
      - module: cadvisor-mine-update
