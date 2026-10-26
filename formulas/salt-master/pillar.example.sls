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

    # The user the salt-master daemon runs as (user: in /etc/salt/master).
    # Everything the daemon must read is owned by / group-readable to this
    # user, not root. Only change this if your packaging differs.
    salt_user: salt
    # gitfs/git_pillar provider — must be gitcli or pygit2; gitpython does
    # not support the privkey/pubkey auth params.
    git_provider: gitcli
    known_host_key: AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl

    # OpenBao (sdb driver) — lets pillar reference sdb://<sdb_profile>/<path>
    # instead of storing secrets in git. role_id isn't secret, it can live
    # here in git; secret_id is a path to a file that must already exist on
    # the master (never committed) — see README.md.
    vault_addr: https://vault.example.internal:8200
    vault_role_id: ""
    vault_secret_id_file: /etc/salt/vault-secret-id

    # Only needed when vault_addr is https with a cert no system trust
    # store knows (self-signed, or an internal CA). Set vault_ca_cert to
    # the PEM itself — public data, fine in git — and the formula writes it
    # to vault_ca_cert_file and points Salt's `verify` at it. Leave empty
    # to omit `verify` entirely (plain http, or a publicly trusted cert).
    vault_ca_cert: |
      -----BEGIN CERTIFICATE-----
      ...
      -----END CERTIFICATE-----
    vault_ca_cert_file: /etc/salt/pki/master/openbao-ca.pem

    # Policies assigned to the token saltext.vault issues for a minion
    # context (pillar rendering is one). Must be a subset of what the
    # master's own AppRole holds, or OpenBao rejects the token.
    vault_policies:
      - salt-master-read

    sdb_profile: osvault
    sdb_kv_path: homelab/data

    # Reactor: full state.apply on every salt/minion/<id>/start event (VM
    # fresh from Tofu, reboot, salt-minion restart). False disables it.
    highstate_on_start: True
    reactor_sls: salt://salt-master/reactor/minion-start.sls
    # Minions re-applied when any minion's Salt Mine entries change (new VM
    # -> Prometheus picks it up). Empty = off.
    mine_consumers:
      - monitoring
    mine_event_tag: homelab/mine/updated
    mine_reactor_sls: salt://salt-master/reactor/mine-updated.sls
    # Services the reactor starts again when a minion's service beacon
    # (formulas/salt-minion) reports them stopped. Empty = off.
    beacon_restart_services:
      - docker
    beacon_service_tag: salt/beacon/*/service/*
    beacon_service_reactor_sls: salt://salt-master/reactor/beacon-service.sls

    # salt-api (rest_cherrypy, HTTPS) for webhooks into the reactor. Cert and
    # key are placed by hand (README "salt-api TLS"); only /hook works.
    api_enabled: False
    api_host: 0.0.0.0
    api_port: 8000
    api_tls_dir: /etc/salt/pki/api
    api_ssl_crt: /etc/salt/pki/api/salt-api.crt
    api_ssl_key: /etc/salt/pki/api/salt-api.key
    # Bearer token Alertmanager sends to /hook/alertmanager. Empty = no
    # mapping. Always from OpenBao:
    api_alertmanager_token: {{ salt['sdb.get']('sdb://osvault/homelab/data/salt-api/alertmanager?token') | yaml_encode }}
    alertmanager_hook_tag: salt/netapi/hook/alertmanager
    alertmanager_reactor_sls: salt://salt-master/reactor/alertmanager-hook.sls
    # Push = deploy: gitfs' update event (fileserver_events) with new commits
    # starts push_orch_sls (formulas/orch).
    push_deploy: False
    push_event_tag: salt/fileserver/gitfs/update
    push_reactor_sls: salt://salt-master/reactor/gitfs-update.sls
    push_orch_sls: orch.push
