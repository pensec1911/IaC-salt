{% from "patchmon-agent/map.jinja" import agent with context %}
{%- if agent.enrolled %}

{#- Upstream's unit (operator guide), Restart=always. #}
patchmon-agent-unit:
  file.managed:
    - name: /etc/systemd/system/{{ agent.unit }}.service
    - contents: |
        # Managed by Salt (formulas/patchmon-agent) — do not edit.
        [Unit]
        Description=PatchMon Agent
        Wants=network-online.target
        After=network-online.target

        [Service]
        Type=simple
        User=root
        ExecStart={{ agent.bin }} serve
        Restart=always
        RestartSec=10
        WorkingDirectory={{ agent.config_dir }}
        SyslogIdentifier={{ agent.unit }}

        [Install]
        WantedBy=multi-user.target

patchmon-agent-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: patchmon-agent-unit

patchmon-agent-service:
  service.running:
    - name: {{ agent.unit }}
    - enable: True
    - require:
      - cmd: patchmon-agent-systemd-reload
    - watch:
      - file: patchmon-agent-binary
      - file: patchmon-agent-unit
      - file: patchmon-agent-credentials
{%- if agent.enroll %}
      - cmd: patchmon-agent-enroll
{%- endif %}
      - file: patchmon-agent-config-server
{%- else %}

patchmon-agent-not-enrolled:
  test.succeed_without_changes:
    - name: "patchmon-agent: not enrolled and no auto-enrollment token (OpenBao patchmon/enroll) — binary installed, service not set up (README)"
{%- endif %}
