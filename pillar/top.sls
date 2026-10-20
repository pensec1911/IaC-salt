base:
  '*':
    - GLOBAL
    - wazuh-agent

  'homepage,monitoring,salt-master':
    - match: list
    - salt-minion-enforce

  'arrstack,jellyfin':
    - match: list
    - salt-minion-enforce-window

  'homepage,monitoring,arrstack,jellyfin':
    - match: list
    - salt-minion-beacons

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
