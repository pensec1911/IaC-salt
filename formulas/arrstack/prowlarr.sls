{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

prowlarr-container:
  docker_container.running:
    - name: {{ arrstack.prowlarr.container_name }}
    - image: {{ arrstack.prowlarr.image }}:{{ arrstack.prowlarr.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - PUID={{ arrstack.puid }}
      - PGID={{ arrstack.pgid }}
      - TZ={{ arrstack.timezone }}
    - binds:
      - {{ arrstack.config_base }}/prowlarr:/config:rw
    - require:
      - docker_container: gluetun-container
      - user: user-media
      - file: arrstack-prowlarr-config-dir
