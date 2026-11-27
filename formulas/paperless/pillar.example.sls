# Real data for this minion goes in pillar/paperless.sls, referenced from
# pillar/top.sls. This file just documents the schema.

# The account the container runs as (formulas/users) — same uid/gid as
# paperless:lookup:uid/gid.
users:
  accounts:
    - name: paperless
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/paperless
      uid: 979
      gid: 979

# Optional: documents on an NFS share (formulas/nfs-mount), owned by 979 on
# the NAS. Name it in paperless:lookup:nfs_mount.
nfs_mounts:
  - name: paperless
    server: 192.168.178.10
    export: /mnt/pool01/documents/paperless
    mountpoint: /mnt/paperless
    opts: [_netdev, rw, noatime]

paperless:
  lookup:
    # Required — sdb references, never literals (README "OpenBao").
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/paperless/app?secret_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/paperless/app?db_password') | yaml_encode }}
    # Required: the external URL (no trailing slash, no path).
    url: https://docs.home.example
    # Optional — overrides for formulas/paperless/map.jinja defaults.
    tag: 3.5.1
    postgres_tag: 18.7-alpine
    valkey_tag: 9.1.3-alpine
    http_port: 8000
    uid: 979
    gid: 979
    allowed_hosts: [localhost, 192.168.178.21]
    timezone: Europe/Berlin
    ocr_language: deu+eng          # bundled in the image: eng deu fra ita spa
    nfs_mount: paperless           # nfs_mounts name -> require mount + create as uid
    media_dir: /mnt/paperless/media
    consume_dir: /mnt/paperless/consume
    consumer_polling_interval: 60  # seconds; NFS has no inotify
    # OIDC login (django-allauth). Empty server_url = off.
    oidc:
      server_url: https://auth.home.example/application/o/paperless/.well-known/openid-configuration
      provider_id: authentik
      name: Authentik
      client_id: paperless
    oidc_client_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-paperless?client_secret') | yaml_encode }}
    # Extra PAPERLESS_* env, merged last. No secrets here.
    config:
      PAPERLESS_TASK_WORKERS: "1"
