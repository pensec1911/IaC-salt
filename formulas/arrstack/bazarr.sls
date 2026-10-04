{% from "arrstack/map.jinja" import arrstack with context %}

include:
  - arrstack.gluetun

{#- Subtitles for Sonarr/Radarr's libraries. Needs the media bind: it writes
   .srt files next to the video files. Talks to Sonarr/Radarr as
   http://localhost:<port> (shared network namespace). #}
bazarr-container:
  docker_container.running:
    - name: {{ arrstack.bazarr.container_name }}
    - image: {{ arrstack.bazarr.image }}:{{ arrstack.bazarr.tag }}
    - restart_policy: unless-stopped
    - network_mode: container:{{ arrstack.gluetun.container_name }}
    - environment:
      - PUID={{ arrstack.puid }}
      - PGID={{ arrstack.pgid }}
      - TZ={{ arrstack.timezone }}
    - binds:
      - {{ arrstack.config_base }}/bazarr:/config:rw
      - {{ arrstack.media_mount }}:/media:rw
    # watch, not just require: see sonarr.sls — when gluetun is recreated
    # its namespace is gone and this container would be left without one.
    - watch:
      - docker_container: gluetun-container
    - require:
      - user: user-media
      - file: arrstack-bazarr-config-dir
      - mount: nfs-mount-media
