# Real data for this minion goes in pillar/jellyfin.sls, referenced from
# pillar/top.sls. This file just documents the schema.
#
# Also requires (in the same pillar file — see formulas/users and
# formulas/nfs-mount):
#   - users:accounts entry "media" with a PINNED uid/gid (must match
#     jellyfin:lookup:puid/pgid below)
#   - nfs_mounts entry named "media" mounted at jellyfin:lookup:media_mount

jellyfin:
  # Optional — overrides for formulas/jellyfin/map.jinja defaults.
  lookup:
    tag: 12.2ubu2604-ls54
    puid: 970
    pgid: 970
    timezone: Etc/UTC
    http_port: 8096
    config_dir: /opt/jellyfin/config
    cache_dir: /opt/jellyfin/cache
    media_mount: /mnt/media   # must match the nfs-mount "media" mountpoint
    # Optional — the URL clients are told to use (auto-discovery etc.).
    published_server_url: "http://192.168.178.24:8096"
