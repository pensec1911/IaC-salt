{% from "arrstack/map.jinja" import arrstack with context %}

{#- gluetun runs internally as root (no PUID/PGID concept), so its own
   config dir stays root-owned — everything else runs as the pinned
   media uid/gid via PUID/PGID or an explicit `User=` — mapped 1:1 into
   each container's user namespace, so the host owners below stay. #}
arrstack-gluetun-config-dir:
  file.directory:
    - name: {{ arrstack.config_base }}/gluetun
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- gluetun's own state; owner left to the container (:U, gluetun.sls). #}
arrstack-gluetun-data-dir:
  file.directory:
    - name: {{ arrstack.config_base }}/gluetun/data
    - require:
      - file: arrstack-gluetun-config-dir

{%- for name in ['qbittorrent', 'sonarr', 'radarr', 'prowlarr', 'bazarr', 'slskd', 'recyclarr'] %}

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

{#- Local disk, not NFS — see incomplete_dir in map.jinja. #}
arrstack-qbittorrent-incomplete-dir:
  file.directory:
    - name: {{ arrstack.qbittorrent.incomplete_dir }}
    - user: {{ arrstack.puid }}
    - group: {{ arrstack.pgid }}
    - mode: '0755'
    - makedirs: True
    - require:
      - user: user-media

{#- Created as puid/pgid directly, not as root and chowned afterwards: the
   NAS squashes root (root_squash), so root on this client can't create
   anything on the share — file.directory fails with PermissionError. The
   share itself is owned by puid/pgid, which can. setpriv instead of runas
   because the media account has a nologin shell. #}
arrstack-incomplete-dir:
  cmd.run:
    - name: setpriv --reuid={{ arrstack.puid }} --regid={{ arrstack.pgid }} --clear-groups install -d -m 0775 {{ arrstack.media_mount }}/incomplete
    - creates: {{ arrstack.media_mount }}/incomplete
    - require:
      - user: user-media
      - mount: nfs-mount-media
