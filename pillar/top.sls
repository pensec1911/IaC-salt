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

  'arrstack':
    - nfs-mount
    - arrstack

  'wazuh':
    - wazuh

  # Per-minion pillar files as needed, e.g.:
  # 'jellyfin':
  #   - jellyfin
