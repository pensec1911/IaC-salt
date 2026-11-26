{% from "hosts/map.jinja" import hosts with context %}

{%- for entry in hosts.entries %}

hosts-{{ entry.ip }}:
  host.present:
    - ip: {{ entry.ip }}
    - names: {{ entry.names | json }}
{%- endfor %}

{%- if not hosts.entries %}

hosts-none:
  test.nop
{%- endif %}
