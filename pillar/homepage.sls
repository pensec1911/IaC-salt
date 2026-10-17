homepage:
  lookup:
    allowed_hosts: "192.168.178.23:3000,homepage:3000,localhost:3000,127.0.0.1:3000"

  settings:
    title: Homelab
    theme: dark
    color: slate

  # Every item gets a status dot (siteMonitor = href) unless it sets
  # `siteMonitor: false` — see formulas/homepage/README.md.
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
          description: Torrents (via Proton VPN)
        - name: slskd
          href: http://192.168.178.22:5030
          icon: slskd.png
          description: Soulseek (via Proton VPN)

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
          widget:
            type: prometheus
            url: http://192.168.178.25:9090
        - name: Wazuh
          href: https://192.168.178.27
          icon: wazuh.png
          description: SIEM / XDR

    # Proxmox cluster nodes (managed by IaC-opentofu, not Salt).
    - name: Proxmox
      items:
        - name: pve01
          href: https://192.168.178.11:8006
          icon: proxmox.png
          description: homepage, wazuh, tailscale-router
        - name: pve02
          href: https://192.168.178.12:8006
          icon: proxmox.png
          description: monitoring, jellyfin, salt-master
        - name: pve03
          href: https://192.168.178.13:8006
          icon: proxmox.png
          description: arrstack, openbao, omada-controller

    - name: Infrastructure
      items:
        - name: TrueNAS
          href: https://192.168.178.10
          icon: truenas-scale.png
          description: NAS — media share
        - name: OpenBao
          href: https://192.168.178.20:8200/ui/
          icon: openbao.png
          description: Secrets
        - name: FRITZ!Box
          href: http://192.168.178.1
          icon: avm-fritzbox.png
          description: Router
