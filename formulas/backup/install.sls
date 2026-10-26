{% from "backup/map.jinja" import backup with context %}

backup-packages:
  pkg.installed:
    - name: {{ backup.pkg }}
