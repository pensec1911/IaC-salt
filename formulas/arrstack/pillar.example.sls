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
      tag: v3.41.3
      # Any gluetun provider name (mullvad, protonvpn, ...).
      vpn_service_provider: protonvpn
      vpn_type: wireguard
      # Required in practice — no sane default (map.jinja). sdb reference,
      # never a literal key.
      wireguard_private_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/gluetun/proton?private_key') | yaml_encode }}
      # Not secret on its own (just the tunnel-internal address the provider
      # assigned this key), but still account-specific — the IPv4 "Address"
      # from the same WireGuard config the private key comes from.
      wireguard_addresses: "10.2.0.2/32"
      # Optional — narrows which servers gluetun picks from.
      server_countries: "Switzerland"
      # Optional, default false. Only for providers that support it (Proton:
      # generate the WireGuard config with NAT-PMP on; Mullvad dropped it).
      # Restricts server choice to port-forwarding servers and pushes the
      # forwarded port into qBittorrent — see README "Port forwarding".
      port_forwarding: true

    qbittorrent:
      tag: 4.6.7
      webui_port: 8080
    sonarr:
      tag: 4.0.20
      port: 8989
    radarr:
      tag: 5.28.0
      port: 7878
    prowlarr:
      tag: 1.37.0
      port: 9696

    bazarr:
      image: lscr.io/linuxserver/bazarr
      tag: 1.6.2
      port: 6767

    flaresolverr:
      image: ghcr.io/flaresolverr/flaresolverr
      tag: v3.5.2
      port: 8191
      log_level: info

    slskd:
      tag: 0.26.1
      webui_port: 5030
      # All four required in practice — no sane defaults. sdb references,
      # never literal values.
      soulseek_username: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?soulseek_username') | yaml_encode }}
      soulseek_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?soulseek_password') | yaml_encode }}
      web_username: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?web_username') | yaml_encode }}
      web_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?web_password') | yaml_encode }}
