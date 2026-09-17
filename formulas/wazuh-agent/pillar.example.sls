# This is the one formula in this repo meant to be referenced from '*' in
# pillar/top.sls (alongside GLOBAL) rather than per-minion — every minion
# that should be monitored gets the same manager address + registration
# secret. See pillar/wazuh-agent.sls for the real values.

wazuh-agent:
  lookup:
    # Required in practice — no sane default (map.jinja). The wazuh
    # minion's LAN address (a bare hostname only works if it resolves —
    # no internal DNS is assumed elsewhere in this repo, so an IP is
    # safer unless you know it resolves).
    manager_address: "192.168.178.X"
    # Required in practice. Must be the exact same sdb secret as
    # formulas/wazuh's manager:registration_password — this is the shared
    # password every agent authenticates enrollment with.
    registration_password: "sdb://osvault/homelab/data/wazuh/registration?password"
