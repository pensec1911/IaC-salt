homepage:
  lookup:
    allowed_hosts: "192.168.178.23:3000,homepage:3000,localhost:3000,127.0.0.1:3000"

  settings:
    title: Homelab
    theme: dark
    color: slate

  services:
    - name: Media
      items:
        - name: Jellyfin
          href: http://192.168.178.24:8096
          icon: jellyfin.png
          description: Media server

    # All arrstack UIs are published by the gluetun container (the others
    # share its network namespace), on the arrstack host.
    - name: Arr
      items:
        - name: Sonarr
          href: http://192.168.178.22:8989
          icon: sonarr.png
          description: Series
        - name: Radarr
          href: http://192.168.178.22:7878
          icon: radarr.png
          description: Movies
        - name: Prowlarr
          href: http://192.168.178.22:9696
          icon: prowlarr.png
          description: Indexers
        - name: Bazarr
          href: http://192.168.178.22:6767
          icon: bazarr.png
          description: Subtitles

    - name: Downloads
      items:
        - name: qBittorrent
          href: http://192.168.178.22:8080
          icon: qbittorrent.png
          description: Torrents (via Mullvad)
        - name: slskd
          href: http://192.168.178.22:5030
          icon: slskd.png
          description: Soulseek (via Mullvad)

    - name: Monitoring
      items:
        - name: Grafana
          href: http://192.168.178.25:3000
          icon: grafana.png
          description: Dashboards
        - name: Prometheus
          href: http://192.168.178.25:9090
          icon: prometheus.png
          description: Metrics

    # Add Wazuh once it's bootstrapped:
    # - name: Infra
    #   items:
    #     - name: Wazuh
    #       href: https://192.168.178.27
    #       icon: wazuh.png
