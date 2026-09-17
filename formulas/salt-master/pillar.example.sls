# Optional overrides for formulas/salt-master. Everything here has a
# working default (see salt-master/map.jinja) — only set what you need to
# change, e.g. if this repo is ever renamed/forked.
salt-master:
  lookup:
    gitfs_remote: git@github.com:pensec1911/IaC-salt.git
    formulas_root: formulas
    states_root: salt
    pillar_root: pillar
    deploy_key_dir: /etc/salt/pki/master/gitfs
    known_host_key: AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl

    # OpenBao (sdb driver) — lets pillar reference sdb://<sdb_profile>/<path>
    # instead of storing secrets in git. role_id isn't secret, it can live
    # here in git; secret_id is a path to a file that must already exist on
    # the master (never committed) — see README.md.
    vault_addr: https://vault.example.internal:8200
    vault_role_id: ""
    vault_secret_id_file: /etc/salt/vault-secret-id
    sdb_profile: osvault
    sdb_kv_path: homelab/data
