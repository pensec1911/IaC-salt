base:
  '*':
    - GLOBAL
    - wazuh-agent

  'homepage,monitoring,salt-master':
    - match: list
    - salt-minion-enforce

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

  'arrstack':
    - nfs-mount
    - arrstack
    - seerr

  'wazuh':
    - wazuh

  'jellyfin':
    - jellyfin
