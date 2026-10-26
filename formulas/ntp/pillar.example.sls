# Pillar for formulas/ntp (systemd-timesyncd). servers is required in
# practice; the rest has working defaults (ntp/map.jinja).
ntp:
  lookup:
    servers:
      - 192.168.178.1
    # Empty = no fallback (clears Debian's debian.pool.ntp.org).
    fallback_servers: []
    pkg: systemd-timesyncd
    service: systemd-timesyncd
    dropin: /etc/systemd/timesyncd.conf.d/salt.conf
