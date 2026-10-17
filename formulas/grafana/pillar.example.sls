# Real data for this minion goes in pillar/grafana.sls, referenced from
# pillar/top.sls. This file just documents the schema.

grafana:
  lookup:
    tag: 11.3.0
    host_port: 3000
    data_dir: /opt/grafana/data
    provisioning_dir: /opt/grafana/provisioning
    dashboards_dir: /opt/grafana/dashboards
    # Grafana folder the provisioned dashboards land in.
    dashboards_folder: Homelab
    admin_user: admin
    # Required in practice — no sane default (see map.jinja). Must be an
    # sdb:// reference resolving to a real secret, never a literal value.
    # Only takes effect the FIRST time the container starts (Grafana's own
    # sqlite db doesn't exist yet) — changing this later does not rotate
    # an already-provisioned admin password. Reset via Grafana's own CLI
    # inside the container if it drifts from pillar.
    admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/grafana/admin?password') | yaml_encode }}
    # uid/gid: must match the image's own internal user (472, "grafana")
    # since no host OS account is created for this — see README.md.
    uid: 472
    gid: 472

  # Rendered 1:1 as the `datasources:` list of a provisioning file
  # (upstream schema). Empty when unset. Use the host IP, not localhost —
  # Grafana runs in its own container.
  datasources:
    - name: Prometheus
      uid: prometheus
      type: prometheus
      access: proxy
      url: http://192.168.178.X:9090
      isDefault: true

  # grafana.com dashboards, downloaded at a pinned revision and checked
  # against sha256. Dashboards removed from this list are deleted.
  # sha256: curl -sL https://grafana.com/api/dashboards/<id>/revisions/<rev>/download | sha256sum
  dashboards:
    - name: node-exporter-full
      gnet_id: 1860
      revision: 45
      sha256: <sha256 of that revision>
