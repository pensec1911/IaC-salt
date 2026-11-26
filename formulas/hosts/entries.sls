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

{#- Containers copy /etc/hosts when they start: restart the ones that must
   resolve the names (only if running — try-restart) whenever an entry
   changes. #}
{%- if hosts.entries and hosts.restart_units %}

hosts-restart-units:
  cmd.run:
    - name: systemctl try-restart {{ hosts.restart_units | join(' ') }}
    - onchanges:
{%- for entry in hosts.entries %}
      - host: hosts-{{ entry.ip }}
{%- endfor %}
{%- endif %}
