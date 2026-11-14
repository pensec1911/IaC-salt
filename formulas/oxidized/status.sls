{% from "oxidized/map.jinja" import oxidized with context %}
{%- if oxidized.enabled %}
{%- set st = oxidized.status %}

include:
  - oxidized.container

{#- oxidized-web is on loopback only (map.jinja), out of blackbox's reach —
   this timer on the host turns its /nodes.json into textfile metrics for
   node-exporter (scraped as job="node", instance="monitoring"). #}
oxidized-status-script:
  file.managed:
    - name: {{ st.script }}
    - source: salt://oxidized/files/oxidized-status.py.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'

oxidized-status-unit:
  file.managed:
    - name: /etc/systemd/system/{{ st.unit }}.service
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        # Managed by Salt (formulas/oxidized) — do not edit.
        [Unit]
        Description=Oxidized device status -> node-exporter textfile
        After={{ oxidized.container_name }}.service

        [Service]
        Type=oneshot
        ExecStart={{ st.script }}
    - require:
      - file: oxidized-status-script

oxidized-status-timer:
  file.managed:
    - name: /etc/systemd/system/{{ st.unit }}.timer
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        # Managed by Salt (formulas/oxidized) — do not edit.
        [Unit]
        Description=Oxidized device status every {{ st.interval }}

        [Timer]
        OnBootSec={{ st.on_boot }}
        OnUnitActiveSec={{ st.interval }}

        [Install]
        WantedBy=timers.target
    - require:
      - file: oxidized-status-unit

oxidized-status-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: oxidized-status-unit
      - file: oxidized-status-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
oxidized-status-timer-running:
  service.running:
    - name: {{ st.unit }}.timer
    - enable: True
    - require:
      - cmd: oxidized-status-systemd-reload
      - sls: node-exporter
      - service: oxidized-container
    - watch:
      - file: oxidized-status-timer
{%- endif %}
