{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

sonarr-container:
  docker_container.running:
    - name: {{ arrstack.sonarr.container_name }}
    - image: {{ arrstack.sonarr.image }}:{{ arrstack.sonarr.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - PUID={{ arrstack.puid }}
      - PGID={{ arrstack.pgid }}
      - TZ={{ arrstack.timezone }}
    - binds:
      - {{ arrstack.config_base }}/sonarr:/config:rw
      - {{ arrstack.media_mount }}:/media:rw
    # watch, not just require: this container lives in gluetun's network
    # namespace, and when gluetun is recreated (image bump, env change) that
    # namespace is gone — the container keeps "running" with no network at
    # all. watch restarts it whenever gluetun changes.
    - watch:
      - docker_container: gluetun-container
    - require:
      - user: user-media
      - file: arrstack-sonarr-config-dir
      - mount: nfs-mount-media
