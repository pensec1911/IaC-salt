# Real data for this minion goes in pillar/forgejo.sls, referenced from
# pillar/top.sls. This file just documents the schema.
#
# Also requires (in the same pillar file — see formulas/users):
#   - users:accounts entry "git" with a PINNED uid/gid (must match
#     forgejo:lookup:uid/gid below)

forgejo:
  # Optional — overrides for formulas/forgejo/map.jinja defaults.
  lookup:
    tag: 15.0.10-rootless
    uid: 972
    gid: 972
    timezone: Etc/UTC
    http_port: 3000        # host port for the web UI
    ssh_port: 2222         # host port for git over SSH, also the port in clone URLs
    data_dir: /opt/forgejo/data
    config_dir: /opt/forgejo/config
    # Merged into the defaults (database, registration off). Each entry becomes FORGEJO__<section>__<KEY>. No secrets here.
    app_ini:
      server:
        DOMAIN: 192.168.178.29
        SSH_DOMAIN: 192.168.178.29
        ROOT_URL: http://192.168.178.29:3000/
      webhook:
        ALLOWED_HOST_LIST: 192.168.178.28
