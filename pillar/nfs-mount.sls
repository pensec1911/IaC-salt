# Referenced only for the 'arrstack' minion (pillar/top.sls) — the media
# share qbittorrent/sonarr/radarr/slskd all bind-mount from. movies/,
# series/, music/ already exist on the NAS side; incomplete/ gets created
# automatically by formulas/arrstack/config.sls the first time this mount
# is live, no manual NAS-side step needed.
nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
