# Referenced only for the 'arrstack' minion (pillar/top.sls) — the media
# share qbittorrent/sonarr/radarr/slskd all bind-mount from. movies/,
# series/, music/ already exist on the NAS side; incomplete/ gets created
# automatically by formulas/arrstack/config.sls the first time this mount
# is live, no manual NAS-side step needed.

# Containers bind the share — Docker must not start before it's mounted
# (empty /mnt/media after a reboot with a slow NAS, 2026-10-17).
nfs-mount:
  lookup:
    required_by:
      - docker.service

nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
