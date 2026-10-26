users:
  accounts:
    # Pinned uid/gid — the rootless container runs as it via a docker
    # `user:` override. Must match forgejo:lookup:uid/gid below. Named "git",
    # not "forgejo": that's the minion's own login account (pillar/GLOBAL.sls).
    - name: git
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/git
      uid: 972
      gid: 972

forgejo:
  lookup:
    uid: 972
    gid: 972
    app_ini:
      server:
        DOMAIN: 192.168.178.29
        SSH_DOMAIN: 192.168.178.29
        ROOT_URL: http://192.168.178.29:3000/
      # Push webhooks to salt-api on the master (formulas/salt-master) —
      # Forgejo only delivers to private IPs that are listed.
      webhook:
        ALLOWED_HOST_LIST: 192.168.178.28
