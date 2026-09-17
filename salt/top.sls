base:
  'salt-master':
    - users
    - salt-master

  'homepage':
    - users
    - docker
    - homepage

  'monitoring':
    - users
    - docker
    - grafana
    - prometheus

  # Targeting is by minion ID, which matches the Tofu VM `name` in
  # IaC-opentofu/vms/<name>/main.tf (set as hostname via cloud-init).
  # Formula names below resolve into ../formulas/<name>/ (gitfs merges
  # formulas/ and salt/ into one flat namespace — see root README).
  # Add one entry per VM as its formula is built out, e.g.:
  # 'jellyfin':
  #   - users
  #   - jellyfin
