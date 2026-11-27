{% from "backup-offsite/map.jinja" import offsite with context %}
{% from "healthchecks-ping/map.jinja" import hc_ping with context %}

backup-offsite-unit:
  file.managed:
    - name: /etc/systemd/system/{{ offsite.unit }}.service
    - source: salt://backup-offsite/files/restic-offsite.service.j2
    - template: jinja
    - require:
      - file: backup-offsite-script
      - file: backup-offsite-env
      - file: backup-offsite-password
      - file: backup-offsite-sources-dir
      - mount: nfs-mount-{{ offsite.mount_name }}
{%- if hc_ping.enabled %}
      - sls: healthchecks-ping
{%- endif %}

backup-offsite-timer:
  file.managed:
    - name: /etc/systemd/system/{{ offsite.unit }}.timer
    - source: salt://backup-offsite/files/restic-offsite.timer.j2
    - template: jinja
    - require:
      - file: backup-offsite-unit

backup-offsite-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: backup-offsite-unit
      - file: backup-offsite-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
backup-offsite-timer-running:
  service.running:
    - name: {{ offsite.unit }}.timer
    - enable: True
    - require:
      - cmd: backup-offsite-systemd-reload
    - watch:
      - file: backup-offsite-timer
