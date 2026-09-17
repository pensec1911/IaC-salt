# Real data for this minion goes in pillar/homepage.sls, referenced from
# pillar/top.sls. This file just documents the schema.

homepage:
  # Optional — overrides for salt/homepage/map.jinja defaults.
  lookup:
    tag: v2.3.0
    host_port: 3000
    config_dir: /opt/homepage/config
    timezone: Etc/UTC
    # Required in practice: every hostname/IP:port homepage will be reached
    # as. Without a match here, homepage 500s with an invalid host header.
    allowed_hosts: "192.168.178.23:3000,homepage:3000,localhost:3000,127.0.0.1:3000"

  # Rendered into settings.yaml. All keys optional.
  settings:
    title: Homelab
    theme: dark
    color: slate

  # Rendered into services.yaml — one entry per dashboard group.
  services:
    - name: Media
      items:
        - name: Jellyfin
          href: http://192.168.178.24:8096
          icon: jellyfin.png
          description: Media server
