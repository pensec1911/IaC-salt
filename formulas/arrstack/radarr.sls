{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

radarr-container:
  docker_container.running:
    - name: {{ arrstack.radarr.container_name }}
    - image: {{ arrstack.radarr.image }}:{{ arrstack.radarr.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - PUID={{ arrstack.puid }}
      - PGID={{ arrstack.pgid }}
      - TZ={{ arrstack.timezone }}
    - binds:
      - {{ arrstack.config_base }}/radarr:/config:rw
      - {{ arrstack.media_mount }}:/media:rw
    - require:
      - docker_container: gluetun-container
      - user: user-media
      - file: arrstack-radarr-config-dir
      - mount: nfs-mount-media
