{% from "jellyfin/map.jinja" import jellyfin with context %}

include:
  - jellyfin.config

{#- Media is bound read-only: Jellyfin only reads the library (metadata and
   artwork live in config_dir), and the arrstack is the only thing that
   should be writing to the share. #}
jellyfin-container:
  docker_container.running:
    - name: {{ jellyfin.container_name }}
    - image: {{ jellyfin.image }}:{{ jellyfin.tag }}
    - restart_policy: unless-stopped
    - port_bindings:
      - {{ jellyfin.http_port }}:8096/tcp
    - environment:
      - PUID={{ jellyfin.puid }}
      - PGID={{ jellyfin.pgid }}
      - TZ={{ jellyfin.timezone }}
      {%- if jellyfin.published_server_url %}
      - JELLYFIN_PublishedServerUrl={{ jellyfin.published_server_url }}
      {%- endif %}
    - binds:
      - {{ jellyfin.config_dir }}:/config:rw
      - {{ jellyfin.cache_dir }}:/cache:rw
      - {{ jellyfin.media_mount }}:/media:ro
    - require:
      - sls: docker
      - user: user-media
      - file: jellyfin-config-dir
      - file: jellyfin-cache-dir
      - mount: nfs-mount-media
