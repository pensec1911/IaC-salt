wazuh:
  lookup:
    # The indexer cert is issued for this IP (config.yml during bootstrap) —
    # must match.
    node_ip: "192.168.178.27"
    # Flip to true only after the manual bootstrap (security init +
    # passwords) — see formulas/wazuh/README.md "Bootstrap".
    bootstrapped: true

    indexer:
      # Indexer "admin" user — Filebeat and the manager authenticate with it,
      # and it's the dashboard login. Set in the indexer with
      # wazuh-passwords-tool.sh during bootstrap.
      admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/indexer-admin?password') | yaml_encode }}

    manager:
      # Shared with pillar/wazuh-agent.sls's registration_password — must
      # be the identical secret.
      registration_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/registration?password') | yaml_encode }}

    # Manager alerts (level >= 10, CVEs only Critical) to Alertmanager on
    # monitoring — formulas/wazuh integration.sls. No auth on :9093.
    alertmanager:
      url: "http://192.168.178.25:9093"

    dashboard:
      # Server API user the dashboard connects as.
      api_wui_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/api?wui_password') | yaml_encode }}
