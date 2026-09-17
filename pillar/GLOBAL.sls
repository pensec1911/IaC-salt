# Applies to every minion (pillar/top.sls: '*': - GLOBAL).
users:
  # One self-named login account per minion — see formulas/users. Password
  # is a single OpenBao secret shared by every account for now (not
  # per-minion) to avoid provisioning one secret per minion up front; see
  # formulas/users/README.md for how to switch to per-minion passwords
  # later. `password` must resolve to an already-hashed value, never
  # plaintext.
  accounts:
    - name: {{ grains['id'] }}
      password: "sdb://osvault/homelab/data/users/shared?password"
      sudo: true
      ssh_authorized_keys: []
        # TODO: add the admin SSH public key(s) here (not secret, fine to
        # commit in plaintext). Left empty for now — the users formula
        # skips ssh_auth.present entries when this list is empty.
