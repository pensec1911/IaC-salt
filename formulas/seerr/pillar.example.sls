# Real data for this minion goes in pillar/seerr.sls, referenced from
# pillar/top.sls. This file just documents the schema.
#
# Also requires (in the same pillar file — see formulas/users):
#   - users:accounts entry "seerr" with a PINNED uid/gid (must match
#     seerr:lookup:uid/gid below)

seerr:
  # Optional — overrides for formulas/seerr/map.jinja defaults.
  lookup:
    tag: v3.5.0
    uid: 971
    gid: 971
    timezone: Etc/UTC
    http_port: 5055
    config_dir: /opt/seerr/config
