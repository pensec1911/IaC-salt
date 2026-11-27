{% from "openbao-snapshot/map.jinja" import openbao_snapshot as ob with context %}
{% from "healthchecks-ping/map.jinja" import hc_ping with context %}

openbao-snapshot-script:
  file.managed:
    - name: {{ ob.script }}
    - source: salt://openbao-snapshot/files/openbao-snapshot.py.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0750'

openbao-snapshot-unit:
  file.managed:
    - name: /etc/systemd/system/{{ ob.unit }}.service
    - source: salt://openbao-snapshot/files/openbao-snapshot.service.j2
    - template: jinja
    - require:
      - file: openbao-snapshot-script
      - file: openbao-snapshot-secret-id-perms
      - file: openbao-snapshot-target-dir
      - test: openbao-snapshot-config-valid
{%- if hc_ping.enabled %}
      - sls: healthchecks-ping
{%- endif %}

openbao-snapshot-timer:
  file.managed:
    - name: /etc/systemd/system/{{ ob.unit }}.timer
    - source: salt://openbao-snapshot/files/openbao-snapshot.timer.j2
    - template: jinja
    - require:
      - file: openbao-snapshot-unit

openbao-snapshot-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: openbao-snapshot-unit
      - file: openbao-snapshot-timer

openbao-snapshot-timer-running:
  service.running:
    - name: {{ ob.unit }}.timer
    - enable: True
    - require:
      - cmd: openbao-snapshot-systemd-reload
    - watch:
      - file: openbao-snapshot-timer
