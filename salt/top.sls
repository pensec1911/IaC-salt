base:
  'salt-master':
    - users
    - ntp
    - wazuh-agent
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - salt-master
    - orch

  'homepage':
    - users
    - ntp
    - wazuh-agent
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - docker
    - cadvisor
    - alloy
    - homepage

  'monitoring':
    - users
    - ntp
    - wazuh-agent
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - docker
    - cadvisor
    - blackbox-exporter
    - loki
    - alloy
    - grafana
    - prometheus
    - alertmanager
    - nfs-mount
    - backup

  'arrstack':
    - users
    - ntp
    - wazuh-agent
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - nfs-mount
    - docker
    - cadvisor
    - alloy
    - arrstack
    - seerr
    - backup

  'wazuh':
    - users
    - ntp
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - wazuh
    - nfs-mount
    - backup

  'jellyfin':
    - users
    - ntp
    - wazuh-agent
    - node-exporter
    - unattended-upgrades
    - salt-minion
    - nfs-mount
    - docker
    - cadvisor
    - alloy
    - jellyfin
    - backup

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
