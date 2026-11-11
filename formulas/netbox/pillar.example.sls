# Real data for this minion goes in pillar/netbox.sls, referenced from
# pillar/top.sls. This file just documents the schema.

netbox:
  lookup:
    # Required — sdb references, never literals (README "OpenBao").
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?secret_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?db_password') | yaml_encode }}
    api_token_pepper: {{ salt['sdb.get']('sdb://osvault/homelab/data/netbox/app?api_token_pepper') | yaml_encode }}
    # Optional — overrides for formulas/netbox/map.jinja defaults.
    tag: v4.7.5-5.1.1
    postgres_tag: 18.6-alpine
    valkey_tag: 9.1.3-alpine
    http_port: 8000            # host port for the web UI (Granian on 8080 inside)
    timezone: Etc/UTC
    base_dir: /opt/netbox
    media_dir: /opt/netbox/media
    postgres_dir: /opt/netbox/postgres
    valkey_dir: /opt/netbox/valkey
    secrets_dir: /opt/netbox/secrets
    dump_dir: /opt/netbox/dump
    # Extra env for the image's configuration.py, merged over the defaults
    # (ALLOWED_HOSTS, SKIP_SUPERUSER, …). No secrets here.
    config:
      TIME_ZONE: Europe/Berlin
