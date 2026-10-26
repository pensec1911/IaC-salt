base:
  '*':
    - GLOBAL
    - wazuh-agent
    - ntp

  'homepage,monitoring,salt-master':
    - match: list
    - salt-minion-enforce

  'arrstack,jellyfin':
    - match: list
    - salt-minion-enforce-window

  'homepage,monitoring,arrstack,jellyfin':
    - match: list
    - salt-minion-beacons

  'arrstack,jellyfin,monitoring,wazuh':
    - match: list
    - backup

  'salt-master':
    - salt-master

  'homepage':
    - homepage

  'monitoring':
    - grafana
    - prometheus
    - alertmanager
    # Read by prometheus' blackbox job (probe targets = homepage items).
    - homepage

  'arrstack':
    - nfs-mount
    - arrstack
    - seerr

  'wazuh':
    - wazuh

  'jellyfin':
    - jellyfin
