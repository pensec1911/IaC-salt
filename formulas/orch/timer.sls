{% from "orch/map.jinja" import orch with context %}
{%- set timer = orch.reboot.timer %}

include:
  - salt-master

orch-reboot-unit:
  file.managed:
    - name: /etc/systemd/system/{{ timer.unit }}.service
    - source: salt://orch/files/orch-reboot.service.j2
    - template: jinja
    - require:
      - sls: salt-master

orch-reboot-timer:
  file.managed:
    - name: /etc/systemd/system/{{ timer.unit }}.timer
    - source: salt://orch/files/orch-reboot.timer.j2
    - template: jinja
    - require:
      - file: orch-reboot-unit

orch-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: orch-reboot-unit
      - file: orch-reboot-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
{%- if timer.enabled %}
orch-reboot-timer-running:
  service.running:
    - name: {{ timer.unit }}.timer
    - enable: True
    - require:
      - cmd: orch-systemd-reload
    - watch:
      - file: orch-reboot-timer
{%- else %}
orch-reboot-timer-stopped:
  service.dead:
    - name: {{ timer.unit }}.timer
    - enable: False
    - require:
      - cmd: orch-systemd-reload
{%- endif %}
