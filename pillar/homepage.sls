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

    # Add more groups/items as other services get their own formula, e.g.:
    # - name: Infra
    #   items:
    #     - name: Wazuh
    #       href: https://192.168.178.27
    #       icon: wazuh.png
