salt-master:
  lookup:
    # Re-applied when a minion's Salt Mine entries change, so Prometheus
    # (scrape targets from the mine) picks up a new VM without a manual run.
    mine_consumers:
      - monitoring

    # Started again by the reactor when a minion's service beacon reports
    # them stopped (pillar/salt-minion-beacons.sls says which minions watch
    # what).
    beacon_restart_services:
      - docker

    # salt-api for webhooks (formulas/salt-master README "salt-api"). TLS
    # cert/key placed by hand on the master; Alertmanager pins the cert
    # (pillar/alertmanager.sls). The token must match the one Alertmanager
    # sends — same OpenBao entry.
    api_enabled: True
    api_alertmanager_token: {{ salt['sdb.get']('sdb://osvault/homelab/data/salt-api/alertmanager?token') | yaml_encode }}

    # Forgejo's push webhook to /hook/git signs with this (HMAC-SHA256);
    # the same secret is set on the webhook in homelab/IaC-salt.
    api_git_hmac_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/salt-api/forgejo?hmac') | yaml_encode }}

    # A push to main deploys itself within ~60 s on the minions that may
    # self-repair right now (orch.push, formulas/orch); the rest keep their
    # nightly window or manual apply.
    push_deploy: True

    # Forgejo's SSH host key (built-in server, :2222), read from
    # /opt/forgejo/data/ssh/gitea.rsa.pub on the minion and matched against
    # ssh-keyscan, 2026-10-26. Public data.
    known_hosts:
      192.168.178.29:
        port: 2222
        enc: ssh-rsa
        key: AAAAB3NzaC1yc2EAAAADAQABAAACAQC8ekmTEyT42SZmnQL+fR443nsym87XYrjkgyv6+VWzHIKFZ0fBXQ0JOHb1JyhRrPun7iUmfrJB+XQ6XmM3Zk1YoziUnDli3KP6kde6Dx5a99V64A1V6kAikiHJiVoc2MRi7BKrwzBvqNaez1CgncqAzJRxAaahdai38ZOPqx9e0V2Ogol7nPjYi/3jvknX/w1hIeOWl4WQjvN6Okg9Vyiw9qVWcHutCt2LxcIpiLzwEe4bPNMW3zuYDS3asJe2H4AbgB/M2vGm+iA8yvlxAhWfWAycRaxgOH6OvmmTl9G2ML/1wmYBtdRMm1fHutQAYS98Uus0jrhoE0zeWrNJzqmCsEyUYz1MxZTywoBJzf4A6OniKB3CZzak7ob82p6JVPPeqB3ch68zOOulKSfOsm2iNcpsECrc4ebaWoYXfDZCNPsBrrDjjyACBARqdgH2yNuifzc+3TAxfI42Gg7EXUht8s0O196JZjAgnyVjvNMHyvytf6VhqKMfNiiLkyPVnVf0Pv2qK3GTdMiFvPFZB9n0yNJHh16JDcQLoUZ3kcgS6GgqtPbaWy73qexVU0wVjVvxV2IwO8zzhAzBrKgGAypqfezfqGREb83Qu1eqQn15EWC3/sOFOMCnccjZzoB23ebbOEd7l/ao8HCXUanogKt2VPfS8cixHfLgyam2+yNrAQ==

    # Not secret — the AppRole role_id from OpenBao. See
    # todo/openbao-setup.md. secret_id (the actual credential) is a file
    # placed manually on the master, never pillar/git — see
    # formulas/salt-master/README.md "OpenBao AppRole".
    vault_role_id: "c0474c8f-8299-707f-c47e-ee49ffced87c"

    # Address the salt-master itself reaches OpenBao on — map.jinja's
    # default is a placeholder (vault.example.internal), so this must be
    # set here or AppRole auth never gets off the ground.
    vault_addr: "https://192.168.178.20:8200"

    # OpenBao's TLS cert — self-signed, so no system trust store knows it
    # and Salt needs it explicitly, or the handshake fails in a way that
    # looks like an auth error. Public data, hence plain in git (not an
    # sdb:// reference). SANs include IP 192.168.178.20, which is what
    # vault_addr connects to — a cert without that SAN can't be verified
    # by IP at all, regardless of trust. Expires 2031-10-02.
    vault_ca_cert: |
      -----BEGIN CERTIFICATE-----
      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
      dspgEA==
      -----END CERTIFICATE-----
