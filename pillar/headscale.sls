{#- formulas/headscale on cloud-edge (OCI). Public: hs.<domain> (A record by
   hand at Porkbun) -> 443/tcp + 3478/udp; metrics only on wg0 for
   Prometheus through the tunnel. #}
{%- set domain = 'ilpaa.xyz' %}
users:
  accounts:
    # Pinned uid/gid — the container runs as it (Podman User=, mapped 1:1).
    # Must match headscale:lookup:uid/gid (map.jinja default 977).
    - name: headscale
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/headscale
      uid: 977
      gid: 977

headscale:
  lookup:
    server_url: https://hs.{{ domain }}
    # MagicDNS suffix for tailnet names (<device>.ts.<domain>), not resolvable
    # outside the tailnet.
    base_domain: ts.{{ domain }}
    metrics_host_ip: 10.99.0.1
    # Policy (HuJSON, rendered as JSON). Transitional (step 4 of the
    # zero-trust plan): the admin's devices reach the whole LAN through
    # gateway; narrowed to edge + admin ports once Caddy/Authentik stand.
    # Tagged nodes (gateway) belong to the tag, not to a user, and never expire.
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
    # <name>.home.<domain> -> edge, filled once Caddy runs (step 5).
    extra_records: []
    # The metrics port is published on the wg0 address — wg0 has to be up
    # before the container binds it.
    podman:
      unit:
        After: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
        Wants: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
