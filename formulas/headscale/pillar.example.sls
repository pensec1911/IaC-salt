users:
  accounts:
    - name: headscale
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/headscale
      uid: 977
      gid: 977

headscale:
  lookup:
    server_url: https://hs.example.com
    base_domain: ts.example.com
    metrics_host_ip: 10.99.0.1
    policy:
      groups:
        "group:admin": ["admin@"]
      tagOwners:
        "tag:gateway": ["group:admin"]
      autoApprovers:
        routes:
          "192.168.178.0/24": ["tag:gateway"]
      acls:
        - action: accept
          src: ["group:admin"]
          dst: ["192.168.178.0/24:*"]
    extra_records:
      - {name: grafana.home.example.com, type: A, value: 192.168.178.30}
    podman:
      unit:
        After: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
        Wants: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
