salt-master:
  lookup:
    # Not secret — the AppRole role_id from OpenBao. See
    # todo/openbao-setup.md. secret_id (the actual credential) is a file
    # placed manually on the master, never pillar/git — see
    # formulas/salt-master/README.md "OpenBao AppRole".
    vault_role_id: "CHANGEME-role-id-from-openbao-approle"
