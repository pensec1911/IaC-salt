# Real data goes in pillar/ntfy.sls, referenced from pillar/top.sls.
#
# Also requires (in the same pillar file — see formulas/users):
#   - users:accounts entry "ntfy" with a PINNED uid/gid (must match
#     ntfy:lookup:uid/gid below)

ntfy:
  # Optional except the three secrets — overrides for
  # formulas/ntfy/map.jinja defaults.
  lookup:
    uid: 974
    gid: 974
    http_port: 8090
    base_url: "http://192.168.178.24:8090"
    cache_duration: 12h
    default_access: deny-all
    admin_user: admin
    publisher_user: alertmanager
    publisher_topics:
      - alerts-*
    # Secrets — OpenBao only, never literal (README "OpenBao").
    admin_password_hash: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/admin?password_hash') | yaml_encode }}
    publisher_password_hash: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/alertmanager?password_hash') | yaml_encode }}
    publisher_token: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/alertmanager?token') | yaml_encode }}
