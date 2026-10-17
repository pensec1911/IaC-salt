# Applies to every minion (pillar/top.sls: '*': - GLOBAL).
users:
  # One self-named login account per minion — see formulas/users. Password
  # is a single OpenBao secret shared by every account for now (not
  # per-minion) to avoid provisioning one secret per minion up front; see
  # formulas/users/README.md for how to switch to per-minion passwords
  # later. `password` must resolve to an already-hashed value, never
  # plaintext.
  #
  # Where the minion ID is also the name of a service's own system user, the
  # login account gets a different name — otherwise the service user becomes
  # a sudo-capable login account (the wazuh package adopted the existing
  # "wazuh" login user for its daemons, 2026-10-17).
  {%- set login_name = {'wazuh': 'wazuh-admin'}.get(grains['id'], grains['id']) %}
  accounts:
    - name: {{ login_name }}
      password: {{ salt['sdb.get']('sdb://osvault/homelab/data/users/shared?password') | yaml_encode }}
      sudo: true
      # Public keys only — not secret. Same "homelab" key OpenTofu injects
      # for the debian cloud-init user (IaC-opentofu terraform.tfvars).
      ssh_authorized_keys:
        - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPueLg6VgGT+b2+3HVaDVMFlOcB0UKIUG+MMwajT3ncp homelab"
