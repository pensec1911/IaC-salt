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
    # salt-api's self-signed cert (formulas/salt-master README "salt-api
    # TLS", SAN IP 192.168.178.28, expires 2031-10-25) — the push webhook
    # to /hook/git verifies against it. Public data; same PEM as in
    # pillar/alertmanager.sls, re-issued: paste the new one in both.
    extra_ca_certs:
      salt-api: |
        -----BEGIN CERTIFICATE-----
        MIIBsDCCAVagAwIBAgIUaSoGYkucZnJssbEDf/GQcCEFCM4wCgYIKoZIzj0EAwIw
        JTEQMA4GA1UECgwHaG9tZWxhYjERMA8GA1UEAwwIc2FsdC1hcGkwHhcNMjYxMDI2
        MTI0MTE0WhcNMzExMDI1MTI0MTE0WjAlMRAwDgYDVQQKDAdob21lbGFiMREwDwYD
        VQQDDAhzYWx0LWFwaTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEhiYHcdChtl
        CFUnk9UR0BmLEn2ZBtNlXky1wZRuiq4zE+W770w6lnlpy8J2SsEPZMwZ7k8jzuMQ
        sk8/z2+K9bujZDBiMB0GA1UdDgQWBBRtKiKSuJBgjpCp/2+OncHETVnOvzAfBgNV
        HSMEGDAWgBRtKiKSuJBgjpCp/2+OncHETVnOvzAPBgNVHREECDAGhwTAqLIcMA8G
        A1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIhAPYFoMyEuLMYHXushxT6
        W7CoeJ9ETeaO2h0cQeXqXn0DAiAyW8FoTWHOeKjOKx4sfijvJalZtsa5VXBNnx+Q
        iIUfNg==
        -----END CERTIFICATE-----
