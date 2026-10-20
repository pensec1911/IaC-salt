users:
  accounts:
    # Pinned uid/gid — the container runs as it via a docker `user:`
    # override. Must match seerr:lookup:uid/gid below.
    - name: seerr
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/seerr
      uid: 971
      gid: 971

seerr:
  lookup:
    uid: 971
    gid: 971
