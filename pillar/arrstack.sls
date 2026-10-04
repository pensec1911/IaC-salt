users:
  accounts:
    # Pinned uid/gid — must match arrstack:lookup:puid/pgid below. See
    # formulas/arrstack/README.md "Dedicated user".
    - name: media
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/media
      uid: 970
      gid: 970

arrstack:
  lookup:
    puid: 970
    pgid: 970

    gluetun:
      wireguard_private_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/gluetun/mullvad?private_key') | yaml_encode }}
      wireguard_addresses: "10.73.117.220/32"   # IPv4 only from the Mullvad config — gluetun has no IPv6 in this container and refuses to start with the v6 address
      server_countries: "Switzerland"

    slskd:
      soulseek_username: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?soulseek_username') | yaml_encode }}
      soulseek_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?soulseek_password') | yaml_encode }}
      web_username: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?web_username') | yaml_encode }}
      web_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/slskd/credentials?web_password') | yaml_encode }}
