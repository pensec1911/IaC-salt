grafana:
  lookup:
    admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/grafana/admin?password') | yaml_encode }}

  # Fixed uids so dashboards/links can reference them. Grafana runs in its
  # own container, so the host IP rather than localhost.
  datasources:
    - name: Prometheus
      uid: prometheus
      type: prometheus
      access: proxy
      url: http://192.168.178.25:9090
      isDefault: true
    - name: Alertmanager
      uid: alertmanager
      type: alertmanager
      access: proxy
      url: http://192.168.178.25:9093
      jsonData:
        implementation: prometheus
    # Logs (formulas/loki), shipped by formulas/alloy on the docker hosts.
    - name: Loki
      uid: loki
      type: loki
      access: proxy
      url: http://192.168.178.25:3100

  # grafana.com dashboards, pinned. To bump: new revision + its sha256
  # (curl -sL <dashboards_source> | sha256sum).
  dashboards:
    - name: node-exporter-full
      gnet_id: 1860
      revision: 45
      sha256: 184c6b7409f306da75525d7772f71945b10cea23ad16b5d78c4698ea0ea51986
    - name: cadvisor
      gnet_id: 19792
      revision: 6
      sha256: 96348d7c68e6d29ced3ba9a8da4358b8605be6815be52daf6d8be85a44f94971
