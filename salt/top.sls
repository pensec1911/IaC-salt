base:
  'salt-master':
    - users
    - wazuh-agent
    - salt-master

  'homepage':
    - users
    - wazuh-agent
    - docker
    - homepage

  'monitoring':
    - users
    - wazuh-agent
    - docker
    - grafana
    - prometheus

  'arrstack':
    - users
    - wazuh-agent
    - nfs-mount
    - docker
    - arrstack

  'wazuh':
    - users
    - wazuh

  # Baseline only for now — no jellyfin formula yet.
  'jellyfin':
    - users
    - wazuh-agent

  # Targeting is by minion ID, which matches the Tofu VM `name` in
  # IaC-opentofu/vms/<name>/main.tf (set as hostname via cloud-init).
  # Formula names below resolve into ../formulas/<name>/ (gitfs merges
  # formulas/ and salt/ into one flat namespace — see root README).
  # Add one entry per VM as its formula is built out, e.g.:
  # '<minion-id>':
  #   - users
  #   - wazuh-agent
  #   - <formula>
