{%- from 'features.jinja' import features %}
{#- Apps behind Caddy on edge link to their https name (urls.<name>, the
   status dot and blackbox probe follow href); appliances with their own
   HTTPS (Proxmox, TrueNAS, OpenBao, FRITZ!Box, Wazuh) stay on the IP. #}
{%- from 'edge-routes.jinja' import edge, urls %}
homepage:
  lookup:
    allowed_hosts: "homepage.{{ edge.domain }},192.168.178.23:3000,homepage:3000,localhost:3000,127.0.0.1:3000"

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
          href: {{ urls['jellyfin'] }}
          icon: jellyfin.png
          description: Media server
        - name: Seerr
          href: {{ urls['seerr'] }}
          icon: seerr.png
          description: Requests

    # All arrstack UIs are published by the gluetun container (the others
    # share its network namespace), on the arrstack host.
    - name: Arr
      items:
        - name: Sonarr
          href: {{ urls['sonarr'] }}
          icon: sonarr.png
          description: Series
        - name: Radarr
          href: {{ urls['radarr'] }}
          icon: radarr.png
          description: Movies
        - name: Prowlarr
          href: {{ urls['prowlarr'] }}
          icon: prowlarr.png
          description: Indexers
        - name: Bazarr
          href: {{ urls['bazarr'] }}
          icon: bazarr.png
          description: Subtitles

    - name: Downloads
      items:
        - name: qBittorrent
          href: {{ urls['qbittorrent'] }}
          icon: qbittorrent.png
          description: Torrents (via Proton VPN)
        - name: slskd
          href: {{ urls['slskd'] }}
          icon: slskd.png
          description: Soulseek (via Proton VPN)

    - name: Monitoring
      items:
        - name: Grafana
          href: {{ urls['grafana'] }}
          icon: grafana.png
          description: Dashboards
        - name: Prometheus
          href: {{ urls['prometheus'] }}
          icon: prometheus.png
          description: Metrics
          widget:
            type: prometheus
            url: http://192.168.178.25:9090
        - name: Alertmanager
          href: {{ urls['alertmanager'] }}
          icon: alertmanager.png
          description: Alerts
        - name: ntfy
          href: {{ urls['ntfy'] }}
          icon: ntfy.png
          description: Alert push notifications
        - name: Healthchecks
          href: {{ urls['healthchecks'] }}
          icon: healthchecks.png
          description: Job heartbeats (dead-man's switch)
        - name: PatchMon
          href: {{ urls['patchmon'] }}
          icon: patchmon.png
          description: Patches per host
{%- if features.wazuh %}
        - name: Wazuh
          href: https://192.168.178.27
          icon: wazuh.png
          description: SIEM / XDR
{%- endif %}

    # Browser toolboxes (formulas/toolbox on monitoring) — client-side only.
    - name: Tools
      items:
        - name: CyberChef
          href: {{ urls['cyberchef'] }}
          icon: sh-cyberchef.png
          description: Encode, decode, crypto, data analysis
        - name: IT-Tools
          href: {{ urls['it-tools'] }}
          icon: it-tools.png
          description: JWT, certs, hashes, regex, cron, subnets

    # Proxmox cluster nodes (managed by IaC-opentofu, not Salt).
    - name: Proxmox
      items:
        - name: pve01
          href: https://192.168.178.11:8006
          icon: proxmox.png
          description: homepage, gateway, edge, openbao (32 GB)
        - name: pve02
          href: https://192.168.178.12:8006
          icon: proxmox.png
          description: monitoring, jellyfin, salt-master
        - name: pve03
          href: https://192.168.178.13:8006
          icon: proxmox.png
          description: arrstack, forgejo

    - name: Infrastructure
      items:
        - name: TrueNAS
          href: https://192.168.178.10
          icon: truenas-scale.png
          description: NAS — media share
        - name: Forgejo
          href: {{ urls['git'] }}
          icon: forgejo.png
          description: Git — deploy source
        - name: NetBox
          href: {{ urls['netbox'] }}
          icon: netbox.png
          description: IPAM / inventory
        - name: OpenBao
          href: https://192.168.178.20:8200/ui/
          icon: openbao.png
          description: Secrets
        - name: FRITZ!Box
          href: http://192.168.178.1
          icon: avm-fritzbox.png
          description: Router
