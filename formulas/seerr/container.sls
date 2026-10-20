{% from "seerr/map.jinja" import seerr with context %}

include:
  - seerr.config

{#- Normal bridge network, not gluetun's namespace: Seerr only talks to
   TMDB and the LAN (Jellyfin, Sonarr, Radarr), nothing that needs the VPN. #}
seerr-container:
  docker_container.running:
    - name: {{ seerr.container_name }}
    - image: {{ seerr.image }}:{{ seerr.tag }}
    - restart_policy: unless-stopped
    - user: "{{ seerr.uid }}:{{ seerr.gid }}"
    - port_bindings:
      - {{ seerr.http_port }}:5055/tcp
    - environment:
      - TZ={{ seerr.timezone }}
    - binds:
      - {{ seerr.config_dir }}:/app/config:rw
    - require:
      - sls: docker
      - user: user-seerr
      - file: seerr-config-dir
