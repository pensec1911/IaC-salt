{% from "arrstack/map.jinja" import arrstack with context %}

{#- gluetun runs internally as root (no PUID/PGID concept), so its own
   config dir stays root-owned — everything else runs as the pinned
   media uid/gid via PUID/PGID or an explicit docker `user:` override. #}
arrstack-gluetun-config-dir:
  file.directory:
    - name: {{ arrstack.config_base }}/gluetun
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{%- for name in ['qbittorrent', 'sonarr', 'radarr', 'prowlarr', 'slskd'] %}

arrstack-{{ name }}-config-dir:
  file.directory:
    - name: {{ arrstack.config_base }}/{{ name }}
    - user: {{ arrstack.puid }}
    - group: {{ arrstack.pgid }}
    - mode: '0755'
    - makedirs: True
    - require:
      - user: user-media
{%- endfor %}

arrstack-incomplete-dir:
  file.directory:
    - name: {{ arrstack.media_mount }}/incomplete
    - user: {{ arrstack.puid }}
    - group: {{ arrstack.pgid }}
    - mode: '0775'
    - makedirs: True
    - require:
      - user: user-media
      - mount: nfs-mount-media
