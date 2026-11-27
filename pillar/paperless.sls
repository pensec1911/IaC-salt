{#- formulas/paperless on docs (.21). Secrets in OpenBao paperless/app and
   authentik/oidc-paperless (formulas/paperless README "OpenBao").
   Documents (originals, archive, inbox) on the NAS: child dataset
   documents/paperless with its own NFS export, only for .21, owned by
   979:979 (roadmap "Paperless-ngx"). Postgres, search index and valkey
   stay on the local disk. #}
{%- from 'edge-routes.jinja' import urls %}
users:
  accounts:
    # Pinned uid/gid — the container runs as it (Podman User=, mapped 1:1);
    # also the owner of the NAS dataset. Must match paperless:lookup:uid/gid.
    - name: paperless
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/paperless
      uid: 979
      gid: 979

# The container binds the share; Quadlet adds RequiresMountsFor= itself.
nfs_mounts:
  - name: paperless
    server: 192.168.178.10
    export: /mnt/pool01/documents/paperless
    mountpoint: /mnt/paperless
    opts:
      - _netdev
      - rw
      - noatime

paperless:
  lookup:
    uid: 979
    gid: 979
    secret_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/paperless/app?secret_key') | yaml_encode }}
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/paperless/app?db_password') | yaml_encode }}
    url: {{ urls['docs'] }}
    # The blackbox upstream probe asks for the IP (pillar/prometheus.sls).
    allowed_hosts: [localhost, 192.168.178.21]
    timezone: Europe/Berlin
    ocr_language: deu+eng
    nfs_mount: paperless
    media_dir: /mnt/paperless/media
    consume_dir: /mnt/paperless/consume
    consumer_polling_interval: 60
    # "Log in with Authentik" (provider paperless, pillar/authentik.sls).
    # The first SSO login creates an unprivileged user — make it superuser
    # once (README "SSO"). The phone apps use the local account / a token.
    oidc:
      server_url: {{ urls['auth'] }}/application/o/paperless/.well-known/openid-configuration
      provider_id: authentik
      name: Authentik
      client_id: paperless
    oidc_client_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/authentik/oidc-paperless?client_secret') | yaml_encode }}
