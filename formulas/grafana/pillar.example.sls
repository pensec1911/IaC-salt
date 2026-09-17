# Real data for this minion goes in pillar/grafana.sls, referenced from
# pillar/top.sls. This file just documents the schema.

grafana:
  lookup:
    tag: 11.3.0
    host_port: 3000
    data_dir: /opt/grafana/data
    admin_user: admin
    # Required in practice — no sane default (see map.jinja). Must be an
    # sdb:// reference resolving to a real secret, never a literal value.
    # Only takes effect the FIRST time the container starts (Grafana's own
    # sqlite db doesn't exist yet) — changing this later does not rotate
    # an already-provisioned admin password. Reset via Grafana's own CLI
    # inside the container if it drifts from pillar.
    admin_password: "sdb://osvault/homelab/data/grafana/admin?password"
    # uid/gid: must match the image's own internal user (472, "grafana")
    # since no host OS account is created for this — see README.md.
    uid: 472
    gid: 472
