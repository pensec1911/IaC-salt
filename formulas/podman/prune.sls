{% from "podman/map.jinja" import podman with context %}

{#- Weekly removal of images nothing references (map.jinja prune). Old tags
   pile up after every bump; on forgejo they filled the root disk
   (2026-11-26). Only the timer is enabled; the service is a oneshot. #}
podman-prune-script:
  file.managed:
    - name: {{ podman.prune.script }}
    - source: salt://podman/files/podman-prune.sh.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - pkg: podman-packages

{%- for kind in ['service', 'timer'] %}

podman-prune-{{ kind }}:
  file.managed:
    - name: /etc/systemd/system/podman-prune.{{ kind }}
    - source: salt://podman/files/podman-prune.{{ kind }}.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
{%- endfor %}

podman-prune-daemon-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: podman-prune-service
      - file: podman-prune-timer

podman-prune-timer-running:
  service.running:
    - name: podman-prune.timer
    - enable: True
    - require:
      - file: podman-prune-script
      - cmd: podman-prune-daemon-reload
