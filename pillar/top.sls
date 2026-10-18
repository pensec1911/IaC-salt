base:
  '*':
    - GLOBAL
    - wazuh-agent

  'homepage,monitoring,salt-master':
    - match: list
    - salt-minion-enforce

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

  'wazuh':
    - wazuh

  'jellyfin':
    - jellyfin
