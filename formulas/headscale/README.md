# headscale formula

Self-hosted Tailscale control server ([Headscale](https://headscale.net)) with its embedded DERP
relay, one container via `formulas/podman`. Runs on `cloud-edge` (OCI): the only host the
outside world reaches. Remote access for the admin's devices; `gateway` is the subnet router
into the LAN (`formulas/tailscale`).

## What it manages

- `/opt/headscale/config/config.yaml` (from pillar), `policy.hujson` (the tailnet policy,
  `headscale:lookup:policy`), `extra-records.json` (MagicDNS records, hot-reloaded).
- `/opt/headscale/data`: SQLite DB, noise + DERP private keys, Let's Encrypt cache, CLI socket.
  Backed up (`pillar/backup.sls`, container stopped for the run).
- The container, as the `headscale` system account (uid/gid 977, `pillar/headscale.sls`).
  Published: `443/tcp` (HTTPS + DERP, TLS-ALPN-01 for the certificate, no :80), `3478/udp`
  (STUN), `/metrics` on `metrics_host_ip:9090` (on cloud-edge the wg0 address, scraped by
  Prometheus through the tunnel).

Config or policy change → container restart (clients reconnect within seconds).
`extra_records` → no restart.

## Pillar

See `pillar.example.sls` and the comment block in `map.jinja`. Required: `server_url`,
`base_domain` (MagicDNS suffix, must differ from `server_url`'s domain).

## Manual steps (security-critical, not automated)

On cloud-edge (`ssh debian@10.99.0.1` from the LAN), CLI through the container:

```sh
alias hs='sudo podman exec headscale headscale'
hs users create admin                      # once
hs users list                              # note admin's ID
# gateway (subnet router): tagged key, 1h, single use -> OpenBao, then highstate gateway
hs preauthkeys create --user <admin-id> --tags tag:gateway --expiration 1h
#   bao kv put -mount=homelab headscale/gateway auth_key=-   (paste, Ctrl-D)
hs nodes list                              # gateway: tag:gateway, no expiry
hs nodes list-routes                       # 192.168.178.0/24 approved (autoApprovers)
# own device (phone/laptop): untagged, expires after node_expiry
hs preauthkeys create --user <admin-id> --expiration 1h
```

Client: Tailscale app → "Use custom control server" / `tailscale up
--login-server=https://hs.<domain> --auth-key=<key>`.

The DNS A record `hs.<domain>` → cloud-edge's reserved public IP is set by hand at Porkbun
(IaC-opentofu README "OCI").

## Checks

```sh
curl -sI https://hs.<domain>/health        # 200, valid Let's Encrypt cert
tailscale netcheck                         # on a client: DERP region 999 "headscale"
```

Prometheus: job `headscale` (metrics), blackbox probe of `https://hs.<domain>/health`
(`ProbeFailed`, `CertificateExpiringSoon`).
