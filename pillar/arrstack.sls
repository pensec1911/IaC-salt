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
      wireguard_private_key: "sdb://osvault/homelab/data/gluetun/mullvad?private_key"
      wireguard_addresses: "CHANGEME"   # fill in from Mullvad's WireGuard config
      server_countries: "Germany"

    slskd:
      soulseek_username: "sdb://osvault/homelab/data/slskd/credentials?soulseek_username"
      soulseek_password: "sdb://osvault/homelab/data/slskd/credentials?soulseek_password"
      web_username: "sdb://osvault/homelab/data/slskd/credentials?web_username"
      web_password: "sdb://osvault/homelab/data/slskd/credentials?web_password"
