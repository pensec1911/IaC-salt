# Referenced from '*' in pillar/top.sls (alongside GLOBAL) — applies to
# every agent-carrying minion identically.
wazuh-agent:
  lookup:
    # An IP, not a hostname: no internal DNS is assumed anywhere in this
    # repo, so "wazuh" would not resolve on the agents.
    manager_address: "192.168.178.27"
    # Shared with pillar/wazuh.sls's manager:registration_password — must
    # be the identical secret.
    registration_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/wazuh/registration?password') | yaml_encode }}
