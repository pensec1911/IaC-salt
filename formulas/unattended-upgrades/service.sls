{% from "unattended-upgrades/map.jinja" import unattended_upgrades with context %}
{%- set uu = unattended_upgrades %}

{%- for timer in uu.apt_timers %}
unattended-upgrades-{{ timer }}:
  service.running:
    - name: {{ timer }}
    - enable: True
    - require:
      - file: unattended-upgrades-dropin
{%- endfor %}

unattended-upgrades-metrics-unit:
  file.managed:
    - name: /etc/systemd/system/{{ uu.metrics.unit }}.service
    - source: salt://unattended-upgrades/files/os-patch-metrics.service.j2
    - template: jinja
    - require:
      - file: unattended-upgrades-metrics-script

unattended-upgrades-metrics-timer:
  file.managed:
    - name: /etc/systemd/system/{{ uu.metrics.unit }}.timer
    - source: salt://unattended-upgrades/files/os-patch-metrics.timer.j2
    - template: jinja
    - require:
      - file: unattended-upgrades-metrics-unit

unattended-upgrades-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: unattended-upgrades-metrics-unit
      - file: unattended-upgrades-metrics-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
unattended-upgrades-metrics-timer-running:
  service.running:
    - name: {{ uu.metrics.unit }}.timer
    - enable: True
    - require:
      - cmd: unattended-upgrades-systemd-reload
    - watch:
      - file: unattended-upgrades-metrics-timer
