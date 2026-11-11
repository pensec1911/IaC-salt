# Real data for this minion goes in pillar/patchmon.sls, referenced from
# pillar/top.sls. This file just documents the schema.

patchmon:
  lookup:
    # Required — the URL browsers use (CORS), and the secrets as sdb
    # references, never literals (README "OpenBao").
    cors_origin: http://192.168.178.29:3001
    jwt_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?jwt_secret') | yaml_encode }}
    session_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?session_secret') | yaml_encode }}
    ai_encryption_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?ai_encryption_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/server?db_password') | yaml_encode }}
    # Optional — overrides for formulas/patchmon/map.jinja defaults.
    tag: '2.1.8'
    postgres_tag: 17.11-alpine
    valkey_tag: 9.1.3-alpine
    http_port: 3001             # host port (3000 inside)
    timezone: Etc/UTC
    base_dir: /opt/patchmon
    postgres_dir: /opt/patchmon/postgres
    valkey_dir: /opt/patchmon/valkey
    dump_dir: /opt/patchmon/dump
    secrets_dir: /opt/patchmon/secrets
    # Extra non-secret env for the server (docker/env.example upstream).
    env:
      LOG_LEVEL: info
