# Self-repair (formulas/salt-minion drift check, enforce mode) for the minions
# listed under this file in pillar/top.sls — hosts where a re-apply is
# harmless, at any hour. arrstack (recreating gluetun restarts the whole VPN
# stack) and jellyfin (a container recreate cuts running streams) only
# repair at night: pillar/salt-minion-enforce-window.sls.
salt-minion:
  lookup:
    drift_check:
      enforce: True
