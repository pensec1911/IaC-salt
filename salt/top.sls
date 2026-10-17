base:
  'salt-master':
    - users
    - wazuh-agent
    - node-exporter
    - salt-master

  'homepage':
    - users
    - wazuh-agent
    - node-exporter
    - docker
    - cadvisor
    - homepage

  'monitoring':
    - users
    - wazuh-agent
    - node-exporter
    - docker
    - cadvisor
    - grafana
    - prometheus
    - alertmanager

  'arrstack':
    - users
    - wazuh-agent
    - node-exporter
    - nfs-mount
    - docker
    - cadvisor
    - arrstack

  'wazuh':
    - users
    - node-exporter
    - wazuh

  'jellyfin':
    - users
    - wazuh-agent
    - node-exporter
    - nfs-mount
    - docker
    - cadvisor
    - jellyfin

  # Targeting is by minion ID, which matches the Tofu VM `name` in
  # IaC-opentofu/vms/<name>/main.tf (set as hostname via cloud-init).
  # Formula names below resolve into ../formulas/<name>/ (gitfs merges
  # formulas/ and salt/ into one flat namespace — see root README).
  # Add one entry per VM as its formula is built out, e.g.:
  # '<minion-id>':
  #   - users
  #   - wazuh-agent
  #   - node-exporter
  #   - <formula>
