{% from "forgejo-runner/map.jinja" import runner with context %}

include:
  - forgejo-runner.container

{#- Every CI job leaves its image and a stopped container in dind
   (dind_dir); 11 GB after a busy day filled forgejo's root disk
   (2026-11-26), and a runner restart orphans running job containers.
   Every 6h: orphans out, then everything older than dind_prune.keep. #}
forgejo-runner-dind-prune-script:
  file.managed:
    - name: {{ runner.dind_prune.script }}
    - source: salt://forgejo-runner/files/dind-prune.sh.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'

{%- for kind in ['service', 'timer'] %}

forgejo-runner-dind-prune-{{ kind }}:
  file.managed:
    - name: /etc/systemd/system/forgejo-runner-dind-prune.{{ kind }}
    - source: salt://forgejo-runner/files/dind-prune.{{ kind }}.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
{%- endfor %}

forgejo-runner-dind-prune-daemon-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: forgejo-runner-dind-prune-service
      - file: forgejo-runner-dind-prune-timer

forgejo-runner-dind-prune-timer-running:
  service.running:
    - name: forgejo-runner-dind-prune.timer
    - enable: True
    - require:
      - file: forgejo-runner-dind-prune-script
      - cmd: forgejo-runner-dind-prune-daemon-reload
