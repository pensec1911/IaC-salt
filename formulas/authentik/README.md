# authentik formula

[Authentik](https://goauthentik.io) on `edge`: the homelab's login. Password + passkey for one
admin, forward auth in front of the Caddy routes with `auth: forward` (`pillar/edge-routes.jinja`),
OIDC for apps that can do it themselves (step 6b of the zero-trust plan). Reached at
`https://auth.home.<domain>` through Caddy.

## What it manages

- `authentik.config`:
  - `/opt/authentik/{data,certs,postgres}` (created only, owner set by the containers via `:U`)
  - `/opt/authentik/secrets/{secret_key,pg_password}` (0700 dir, 0444 files, from OpenBao)
  - `/opt/authentik/dump` (pg_dump target for formulas/backup)
  - `/opt/authentik/blueprints` (rendered from `files/blueprints/`, read-only in the worker)
- `authentik.container`, on the Podman network `edge` (owned by `formulas/caddy`, so Caddy reaches
  `authentik-server:9000` by name):
  - `authentik-postgres` (image user 70:70, its data dir via `:U`)
  - `authentik-server` (`ak server`, metrics published on `:9300`)
  - `authentik-worker` (`ak worker`, shares the server's user namespace, applies the blueprints;
    no docker socket, not root)

## Blueprints

Applied by the worker on change and hourly. Objects created by hand in the UI stay as they are.

| File | What |
|---|---|
| `10-passkey.yaml` | Default login flow: after the password, a passkey is required. A user without one registers it right there (WebAuthn setup), so the first login after the initial setup asks for it. |
| `40-forward-auth.yaml` | Proxy provider `homelab-forward-auth` (forward_domain, cookie on `<domain>`), application, binding to `admin_group` (default `authentik Admins`), assigned to the embedded outpost. |

## Pillar

See `pillar.example.sls` and `map.jinja`. Required: `domain`, `external_host`, `secret_key`,
`pg_password` (OpenBao `authentik/app`):

```sh
openssl rand 60 | base64 -w 0 | bao kv put -mount=homelab authentik/app secret_key=-
openssl rand -hex 24 | bao kv patch -mount=homelab authentik/app pg_password=-
```

`pillar/caddy.sls` turns Caddy's forward auth on only once `authentik/app` exists, so the routes
stay reachable before Authentik runs.

## Manual steps (security-critical, not automated)

1. **Initial setup**: `https://auth.home.<domain>/if/flow/initial-setup/` (open until done):
   set a password for `akadmin`, store it in the password manager. Its e-mail can stay a dummy.
2. **Log out and back in**: after the password, Authentik asks to register a passkey (phone or
   security key). From then on every login needs it.
3. **Second passkey / recovery**: register a second authenticator in the user settings (e.g. the
   laptop's platform key or a second phone). If all are lost:
   `sudo podman exec -it authentik-worker ak create_recovery_key 10 akadmin` on edge gives a
   one-time recovery link valid for 10 minutes.
4. Optional: a personal user instead of akadmin — create it in the UI, add it to `authentik Admins`.

## Checks

```sh
curl -sI https://auth.home.<domain>/-/health/live/        # 200
curl -sI https://sonarr.home.<domain>/                    # 302 -> auth.home.<domain>
sudo podman logs authentik-worker | grep -i blueprint     # applied, no errors
```

Prometheus: job `authentik` (`edge:9300`). Backup: `/opt/authentik` without postgres, secrets and
blueprints, plus a `pg_dump` of `authentik` (`pillar/backup.sls`).

## Emergency access

If Authentik is down, every `auth: forward` route answers with an error. The apps themselves
still answer on their IP:port from the LAN (and through the tailnet until the ACL is narrowed).
