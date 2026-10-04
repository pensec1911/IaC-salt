{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

{#- slskd doesn't support PUID/PGID (that's an LSIO-image convention, and
   this isn't an LSIO image) — pinned uid:gid passed directly via `user:`
   instead, same approach as formulas/grafana and formulas/prometheus. #}
slskd-container:
  docker_container.running:
    - name: {{ arrstack.slskd.container_name }}
    - image: {{ arrstack.slskd.image }}:{{ arrstack.slskd.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - user: "{{ arrstack.puid }}:{{ arrstack.pgid }}"
    - environment:
      - SLSKD_SLSKD_USERNAME={{ arrstack.slskd.web_username }}
      - SLSKD_SLSKD_PASSWORD={{ arrstack.slskd.web_password }}
      - SLSKD_SOULSEEK_USERNAME={{ arrstack.slskd.soulseek_username }}
      - SLSKD_SOULSEEK_PASSWORD={{ arrstack.slskd.soulseek_password }}
      - SLSKD_DOWNLOADS_DIR=/media/incomplete
      - SLSKD_INCOMPLETE_DIR=/media/incomplete
    - binds:
      - {{ arrstack.config_base }}/slskd:/app:rw
      - {{ arrstack.media_mount }}:/media:rw
    # watch, not just require: this container lives in gluetun's network
    # namespace, and when gluetun is recreated (image bump, env change) that
    # namespace is gone — the container keeps "running" with no network at
    # all. watch restarts it whenever gluetun changes.
    - watch:
      - docker_container: gluetun-container
    - require:
      - user: user-media
      - file: arrstack-slskd-config-dir
      - cmd: arrstack-incomplete-dir
      - mount: nfs-mount-media
