{#- formulas/headscale on cloud-edge (OCI). Public: hs.<domain> (A record by
   hand at Porkbun) -> 443/tcp + 3478/udp; metrics only on wg0 for
   Prometheus through the tunnel. #}
{%- set domain = 'ilpaa.xyz' %}
{%- from 'edge-routes.jinja' import edge, routes %}
{#- What the admin's tailnet devices (laptop, phone) may reach in the LAN
   through gateway. Every web UI goes through Caddy on edge (*.home names,
   Authentik in front); direct IP:port only for non-HTTP admin access and
   the clients that use IPs (Tofu: Proxmox API, OpenBao, tofu-state,
   NetBox API). Everything else is denied — also at home, since the laptop
   routes the LAN through the tailnet. Confirmed by the user 2026-11-26. #}
{%- set admin_access = [
    (edge.ip,          '80,443'),
    ('192.168.178.22', '22'),
    ('192.168.178.23', '22'),
    ('192.168.178.24', '22'),
    ('192.168.178.25', '22'),
    ('192.168.178.28', '22'),
    ('192.168.178.29', '22,2222,5432,8000'),
    ('192.168.178.30', '22'),
    ('192.168.178.31', '22'),
    ('192.168.178.11', '22,8006'),
    ('192.168.178.12', '22,8006'),
    ('192.168.178.13', '22,8006'),
    ('192.168.178.20', '22,8200'),
    ('192.168.178.10', '22,80,443'),
    ('192.168.178.1',  '53,80,443'),
] %}
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
    # Policy (HuJSON, rendered as JSON). The admin's devices reach only
    # admin_access above; implicit deny for the rest. The whole subnet is
    # still advertised (gateway) — the ACL filters, not the route.
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
          dst:
{%- for ip, ports in admin_access %}
            - "{{ ip }}:{{ ports }}"
{%- endfor %}
    # The edge zone as search domain: clients (systemd-resolved on the
    # laptop) then ask only the tailnet for *.home.<domain> instead of racing
    # it against the LAN/public resolver, where Porkbun's wildcard answers.
    search_domains: [{{ edge.domain }}]
    # <name>.home.<domain> -> edge (formulas/caddy), one A record per route
    # (no wildcards in extra_records). Hot-reloaded, no restart.
    extra_records:
{%- for r in routes %}
      - {name: {{ r.name }}.{{ edge.domain }}, type: A, value: {{ edge.ip }}}
{%- endfor %}
    # The metrics port is published on the wg0 address — wg0 has to be up
    # before the container binds it.
    podman:
      unit:
        After: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
        Wants: [wg-quick@wg0.service]  # secret-scan: allow (systemd unit, not an e-mail)
