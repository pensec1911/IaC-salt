# Real data for this minion goes in pillar/tofu-state.sls, referenced from
# pillar/top.sls. This file just documents the schema.

tofu-state:
  lookup:
    # Required — sdb reference, never a literal (README "OpenBao").
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/tofu-state/postgres?password') | yaml_encode }}
    # Optional — overrides for formulas/tofu-state/map.jinja defaults.
    tag: 18.6-alpine
    postgres_port: 5432
    db_name: tofu
    db_user: tofu
    base_dir: /opt/tofu-state
    data_dir: /opt/tofu-state/postgres
    secrets_dir: /opt/tofu-state/secrets
    dump_dir: /opt/tofu-state/dump
