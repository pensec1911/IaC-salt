{% from "arrstack/map.jinja" import arrstack with context %}
{%- set rc = arrstack.recyclarr %}

include:
  - arrstack.sonarr
  - arrstack.radarr

{#- Pulled here so the timer never pulls at run time (pinned tag). #}
recyclarr-image:
  docker_image.present:
    - name: {{ rc.image }}
    - tag: {{ rc.tag }}

{#- No secrets in here — api_key is !env_var, filled by the sync script. #}
recyclarr-config:
  file.managed:
    - name: {{ arrstack.config_base }}/recyclarr/recyclarr.yml
    - source: salt://arrstack/files/recyclarr.yml.j2
    - template: jinja
    - user: {{ arrstack.puid }}
    - group: {{ arrstack.pgid }}
    - mode: '0644'
    - require:
      - file: arrstack-recyclarr-config-dir

recyclarr-script:
  file.managed:
    - name: {{ rc.script }}
    - source: salt://arrstack/files/recyclarr-sync.sh.j2
    - template: jinja
    - mode: '0755'
    - require:
      - sls: node-exporter

recyclarr-unit:
  file.managed:
    - name: /etc/systemd/system/{{ rc.unit }}.service
    - source: salt://arrstack/files/recyclarr-sync.service.j2
    - template: jinja
    - require:
      - file: recyclarr-script
      - file: recyclarr-config
      - docker_image: recyclarr-image
      - docker_container: sonarr-container
      - docker_container: radarr-container

recyclarr-timer:
  file.managed:
    - name: /etc/systemd/system/{{ rc.unit }}.timer
    - source: salt://arrstack/files/recyclarr-sync.timer.j2
    - template: jinja
    - require:
      - file: recyclarr-unit

recyclarr-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: recyclarr-unit
      - file: recyclarr-timer

{#- Only the timer runs permanently; the service is a oneshot it starts. #}
recyclarr-timer-running:
  service.running:
    - name: {{ rc.unit }}.timer
    - enable: True
    - require:
      - cmd: recyclarr-systemd-reload
    - watch:
      - file: recyclarr-timer
