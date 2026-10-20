{% from "seerr/map.jinja" import seerr with context %}

{#- Local disk, not the NAS: config holds Seerr's SQLite DB and
   settings.json (incl. the Jellyfin/Sonarr/Radarr API keys entered in the
   setup wizard), which don't belong on NFS. #}
seerr-config-dir:
  file.directory:
    - name: {{ seerr.config_dir }}
    - user: {{ seerr.uid }}
    - group: {{ seerr.gid }}
    - mode: '0750'
    - makedirs: True
    - require:
      - user: user-seerr
