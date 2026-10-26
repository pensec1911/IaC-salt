{#- formulas/ntp, every minion: the FRITZ!Box is the one time source (it
   answers NTP on its LAN address, stratum 2). No fallback — see the
   formula README. #}
ntp:
  lookup:
    servers:
      - 192.168.178.1
    fallback_servers: []
