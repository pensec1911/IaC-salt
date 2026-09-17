# Real data for this minion goes in pillar/wazuh.sls, referenced from
# pillar/top.sls. This file just documents the schema.
#
# Requires the TLS certs and indexer security bootstrap to already exist
# on this minion BEFORE state.apply succeeds — see README.md "TLS
# bootstrap (manual, one-time)". Nothing in this formula generates them.

wazuh:
  lookup:
    indexer:
      # Required in practice — no sane default (map.jinja).
      admin_password: "sdb://osvault/homelab/data/wazuh/indexer-admin?password"
      # Must be byte-for-byte the Subject DN used when generating the
      # certs during the TLS bootstrap — not secret, but there's no sane
      # default, and a mismatch here means the indexer security plugin
      # rejects the manager/dashboard outright.
      admin_dn: "CN=admin,O=Wazuh,OU=Wazuh,L=California,C=US"
      node_dn: "CN=wazuh-indexer-1,O=Wazuh,OU=Wazuh,L=California,C=US"
      # node_name/cluster_name/certs_dir/network_host all have working
      # defaults (map.jinja) — only set if you changed them during bootstrap.

    manager:
      # Required in practice — shared with formulas/wazuh-agent's
      # registration_password, must be the same sdb secret.
      registration_password: "sdb://osvault/homelab/data/wazuh/registration?password"

    dashboard:
      server_port: 443
