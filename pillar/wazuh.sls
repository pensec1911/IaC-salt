wazuh:
  lookup:
    indexer:
      admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/indexer-admin?password') | yaml_encode }}
      # Must exactly match the Subject DN used generating the TLS certs
      # during the manual bootstrap — see formulas/wazuh/README.md.
      admin_dn: "CHANGEME-must-match-cert-bootstrap"
      node_dn: "CHANGEME-must-match-cert-bootstrap"

    manager:
      # Shared with pillar/wazuh-agent.sls's registration_password — must
      # be the identical secret.
      registration_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/registration?password') | yaml_encode }}
