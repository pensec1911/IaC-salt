users:
  accounts:
    # Same pinned account as the arrstack (pillar/arrstack.sls) — files on
    # the shared media share are owned by it. Must match
    # jellyfin:lookup:puid/pgid below.
    - name: media
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/media
      uid: 970
      gid: 970

# Same share the arrstack writes to, mounted read-only here — Jellyfin only
# reads the library.
nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
    opts:
      - _netdev
      - ro
      - noatime

jellyfin:
  lookup:
    puid: 970
    pgid: 970
    published_server_url: "http://192.168.178.24:8096"
