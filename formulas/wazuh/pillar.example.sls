# Real data for this minion goes in pillar/wazuh.sls, referenced from
# pillar/top.sls. This file just documents the schema. Read README.md
# "Bootstrap" first — several steps are manual and ordered.

wazuh:
  lookup:
    # Pins wazuh-indexer/-manager/-dashboard AND the Filebeat alerts template
    # tag. Bump all at once, deliberately.
    version: "4.14.9"
    # Required — the IP the certs are issued for (config.yml).
    node_ip: "192.168.178.27"
    # false until the manual security init + password step is done.
    # Gates keystores, wazuh.yml, Filebeat and the dashboard service.
    bootstrapped: false
    # Where you put the output of wazuh-certs-tool.sh -A.
    certs_tar: /root/wazuh-certificates.tar

    indexer:
      # Must match the indexer node name in config.yml. Default = Wazuh's
      # template name, which the shipped opensearch.yml already expects.
      node_name: node-1
      # Optional — only if your cert's subject differs from the
      # wazuh-certs-tool default (README "Bootstrap" step 2 checks this).
      # node_dn: "CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US"
      # Required in practice. sdb reference, never a literal.
      admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/indexer-admin?password') | yaml_encode }}

    manager:
      node_name: wazuh-1        # server node name in config.yml
      # Shared with formulas/wazuh-agent — the same sdb secret.
      registration_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/registration?password') | yaml_encode }}

    # Optional — empty url = no integration. Alertmanager base URL.
    alertmanager:
      url: "http://192.168.178.25:9093"
      level: 10                     # integratord: rule level >= this
      vulnerability_min_level: 13   # CVE alerts: Critical only
      resolve_after_hours: 24

    dashboard:
      node_name: dashboard      # dashboard node name in config.yml
      server_port: 443
      api_wui_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/api?wui_password') | yaml_encode }}
