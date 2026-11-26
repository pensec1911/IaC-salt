# caddy formula

Reverse proxy for the homelab's web UIs on `edge`: `https://<name>.home.<domain>` → the app,
with one Let's Encrypt wildcard certificate (`*.home.<domain>`, DNS-01 at Porkbun). Nothing is
public: the names resolve only on the LAN minions (`formulas/hosts`) and for tailnet clients
(Headscale MagicDNS records). The route list is `pillar/edge-routes.jinja`. From step 6 of the
zero-trust plan on, Authentik sits in front of the routes with `auth: forward`.

## What it manages

- `caddy.image`: builds `localhost/caddy-porkbun:<caddy>-porkbun<plugin>` on the minion from
  `files/Containerfile` (stock image + `xcaddy build --with github.com/caddy-dns/porkbun`).
  Only when that tag is missing, so the first apply and every version bump take ~2 min longer.
  No registry is involved, so there's no chicken-and-egg problem with a registry behind this
  Caddy. Renovate bumps `tag` (regex manager, docker) and `porkbun_version` (regex manager, go).
- `caddy.config`: `/opt/caddy/config/Caddyfile` (rendered from pillar), `/opt/caddy/data`
  (certificates + ACME account, backed up) and `/opt/caddy/state` (autosave), both owned by the
  `caddy` account (uid/gid 978, `pillar/caddy.sls`).
- `caddy.container`: the Podman network `edge` (shared with Authentik later) and the container
  as `caddy`, read-only root. Published: `443` (→ 8443), `80` (→ 8080, only redirects to
  https), `9180` (Prometheus `/metrics`). The admin API stays on localhost inside the
  container. Porkbun keys come in through the 0600 secret env file.

A Caddyfile change restarts the container (a few seconds without proxy).

## Pillar

See `pillar.example.sls` and the comment block in `map.jinja`. Required: `domain`,
`porkbun_api_key`, `porkbun_secret_api_key` (OpenBao `porkbun/api`, keys `api_key`,
`secret_api_key`). The Porkbun domain needs "API Access" switched on.

## Add a route

One line in `pillar/edge-routes.jinja`. Caddyfile, `/etc/hosts` on the LAN minions, the Headscale
DNS records, the upstream probe and (via `urls.<name>` in `pillar/homepage.sls`) the homepage
link all follow from it. Then apply `edge`, `cloud-edge` and the minions that use the name.

## Cold start / no internet

The built image stays local; Quadlet never pulls it. If it's gone (new VM) and the build fails,
the proxy is down, but every app still answers on its IP:port from the LAN.

## Checks

```sh
curl -sI https://grafana.home.<domain>          # from any LAN minion or tailnet device
sudo podman logs caddy | grep -i certificate    # obtaining / renewal
curl -s http://192.168.178.30:9180/metrics | head
```

crt.sh for the domain shows only `*.home.<domain>`, never single host names.
Prometheus: job `caddy`, blackbox probes per name (homepage) and per upstream
(`blackbox-upstream`), `CertificateExpiringSoon` covers the wildcard.
