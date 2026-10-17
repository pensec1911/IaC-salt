{% from "jellyfin/map.jinja" import jellyfin with context %}

{#- Both local, not on the NAS: config holds Jellyfin's SQLite library DB,
   which doesn't belong on NFS, and cache is transcode/image scratch. #}
{%- for name, path in [('config', jellyfin.config_dir), ('cache', jellyfin.cache_dir)] %}

jellyfin-{{ name }}-dir:
  file.directory:
    - name: {{ path }}
    - user: {{ jellyfin.puid }}
    - group: {{ jellyfin.pgid }}
    - mode: '0755'
    - makedirs: True
    - require:
      - user: user-media
{%- endfor %}
