base:
  '*':
    - GLOBAL
    - wazuh-agent

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
