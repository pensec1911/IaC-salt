# Real data for this minion goes in pillar/arrstack.sls, referenced from
# pillar/top.sls. This file just documents the schema.
#
# Also requires (see pillar/nfs-mount.sls and their own pillar.example.sls):
#   - users:accounts entry "media" with a PINNED uid/gid (must match
#     arrstack:lookup:puid/pgid below — see formulas/users)
#   - nfs_mounts entry named "media" mounted at arrstack:lookup:media_mount

arrstack:
  lookup:
    puid: 970
    pgid: 970
    timezone: Etc/UTC
    config_base: /opt/arrstack
    media_mount: /mnt/media   # must match the nfs-mount "media" mountpoint

    gluetun:
      tag: v3.39.1
      vpn_service_provider: mullvad
      vpn_type: wireguard
      # Required in practice — no sane default (map.jinja). sdb reference,
      # never a literal key.
      wireguard_private_key: "sdb://osvault/homelab/data/gluetun/mullvad?private_key"
      # Not secret on its own (just the tunnel-internal address Mullvad
      # assigned this key), but still account-specific — from the same
      # WireGuard config Mullvad gives you the private key from.
      wireguard_addresses: "10.x.x.x/32"
      # Optional — narrows which Mullvad servers gluetun picks from.
      server_countries: "Germany"

    qbittorrent:
      tag: 4.6.7
      webui_port: 8080
    sonarr:
      tag: 4.0.9
      port: 8989
    radarr:
      tag: 5.10.4
      port: 7878
    prowlarr:
      tag: 1.24.3
      port: 9696

    slskd:
      tag: 0.21.3
      webui_port: 5030
      # All four required in practice — no sane defaults. sdb references,
      # never literal values.
      soulseek_username: "sdb://osvault/homelab/data/slskd/credentials?soulseek_username"
      soulseek_password: "sdb://osvault/homelab/data/slskd/credentials?soulseek_password"
      web_username: "sdb://osvault/homelab/data/slskd/credentials?web_username"
      web_password: "sdb://osvault/homelab/data/slskd/credentials?web_password"
