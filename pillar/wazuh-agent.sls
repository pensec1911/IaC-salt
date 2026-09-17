# Referenced from '*' in pillar/top.sls (alongside GLOBAL) — applies to
# every agent-carrying minion identically.
wazuh-agent:
  lookup:
    # Fill in once the wazuh VM is provisioned and has a real address —
    # no internal DNS is assumed elsewhere in this repo, so this should
    # be an IP, not a bare hostname, unless you know "wazuh" resolves.
    manager_address: "CHANGEME-wazuh-vm-ip"
    # Shared with pillar/wazuh.sls's manager:registration_password — must
    # be the identical secret.
    registration_password: "sdb://osvault/homelab/data/wazuh/registration?password"
