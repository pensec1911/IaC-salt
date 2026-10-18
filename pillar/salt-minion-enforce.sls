# Self-repair (formulas/salt-minion drift check, enforce mode) for the minions
# listed under this file in pillar/top.sls — hosts where a re-apply is
# harmless. Not arrstack (recreating gluetun restarts the whole VPN stack)
# and not jellyfin (a container recreate cuts running streams).
salt-minion:
  lookup:
    drift_check:
      enforce: True
