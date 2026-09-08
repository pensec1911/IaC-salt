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
