{% from "backup/map.jinja" import backup with context %}

backup-unit:
  file.managed:
    - name: /etc/systemd/system/{{ backup.unit }}.service
    - source: salt://backup/files/restic-backup.service.j2
    - template: jinja
    - require:
      - file: backup-script
      - file: backup-env-file
      - file: backup-password-file
      - mount: nfs-mount-{{ backup.mount_name }}

backup-timer:
  file.managed:
    - name: /etc/systemd/system/{{ backup.unit }}.timer
    - source: salt://backup/files/restic-backup.timer.j2
    - template: jinja
    - require:
      - file: backup-unit

{#- Weekly restore test (map.jinja restore_test): same env and share, no
   container stops — it only reads the repo. #}
backup-restore-test-unit:
  file.managed:
    - name: /etc/systemd/system/{{ backup.restore_test.unit }}.service
    - source: salt://backup/files/restic-restore-test.service.j2
    - template: jinja
    - require:
      - file: backup-restore-test-script
      - file: backup-env-file
      - file: backup-password-file
      - mount: nfs-mount-{{ backup.mount_name }}

backup-restore-test-timer:
  file.managed:
    - name: /etc/systemd/system/{{ backup.restore_test.unit }}.timer
    - source: salt://backup/files/restic-restore-test.timer.j2
    - template: jinja
    - require:
      - file: backup-restore-test-unit

backup-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: backup-unit
      - file: backup-timer
      - file: backup-restore-test-unit
      - file: backup-restore-test-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
backup-timer-running:
  service.running:
    - name: {{ backup.unit }}.timer
    - enable: True
    - require:
      - cmd: backup-systemd-reload
    - watch:
      - file: backup-timer

backup-restore-test-timer-running:
  service.running:
    - name: {{ backup.restore_test.unit }}.timer
    - enable: True
    - require:
      - cmd: backup-systemd-reload
    - watch:
      - file: backup-restore-test-timer
