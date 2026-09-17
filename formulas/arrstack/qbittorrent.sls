{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

qbittorrent-container:
  docker_container.running:
    - name: {{ arrstack.qbittorrent.container_name }}
    - image: {{ arrstack.qbittorrent.image }}:{{ arrstack.qbittorrent.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - PUID={{ arrstack.puid }}
      - PGID={{ arrstack.pgid }}
      - TZ={{ arrstack.timezone }}
      - WEBUI_PORT={{ arrstack.qbittorrent.webui_port }}
    - binds:
      - {{ arrstack.config_base }}/qbittorrent:/config:rw
      - {{ arrstack.media_mount }}:/media:rw
    - require:
      - docker_container: gluetun-container
      - user: user-media
      - file: arrstack-qbittorrent-config-dir
      - mount: nfs-mount-media
