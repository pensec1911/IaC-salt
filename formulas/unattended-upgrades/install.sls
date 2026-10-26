{% from "unattended-upgrades/map.jinja" import unattended_upgrades with context %}

unattended-upgrades-packages:
  pkg.installed:
    - name: {{ unattended_upgrades.pkg }}
