# ntfy formula

Runs [ntfy](https://ntfy.sh) ([binwiederhier/ntfy](https://hub.docker.com/r/binwiederhier/ntfy))
as a Podman container (Quadlet unit via `formulas/podman`) — self-hosted push notifications.
Alertmanager on monitoring publishes its alerts here (`pillar/alertmanager.sls`); the ntfy
phone app (or the web app) subscribes. Depends on the `podman` and `users` formulas.

Runs on jellyfin, not monitoring: alerts must still go out when monitoring is in trouble. Both
VMs share Proxmox node pve02, so a pve02 outage still silences both — that's for an external
heartbeat (roadmap "Healthchecks"), not for this formula.

## What it manages

- `ntfy.config` — fails with `ntfy-secrets-valid` if one of the three secrets below is empty or
  unresolved (ntfy never starts with an empty credential). `/opt/ntfy/config/server.yml`
  (root:`ntfy` 0640, diff hidden — holds password hashes and the token) and
  `/opt/ntfy/data` (`ntfy` 974:974: `auth.db` users/ACLs/tokens, `cache.db` 12 h message buffer).
- `ntfy.container` — the container, as `ntfy` (974, mapped 1:1), read-only root, listening on
  8080 inside, published on `http_port` (8090). Restarts when `server.yml` changes.

## Auth (declarative)

`auth-default-access: deny-all`, login required in the web app, no signup. Users, ACLs and
tokens are **provisioned from `server.yml`** (`auth-users`, `auth-access`, `auth-tokens`): ntfy
syncs them into `auth.db` on every start and deletes provisioned entries no longer listed. No
`ntfy user add` / `ntfy token add` needed — nothing to do by hand after the first start.

| User | Role | Access | Used by |
|---|---|---|---|
| `admin` | admin | everything | phone app / web app login |
| `alertmanager` | user | write-only on `alerts-*` | Alertmanager, via its token (`Authorization: Bearer`) |
| `healthchecks` | user | write-only on `alerts-critical` | Healthchecks' ntfy integration (`formulas/healthchecks`), via its token; only declared once `ntfy/healthchecks` resolves (`extra_publishers`) |

Topics: `alerts-critical`, `alerts-warning` (Alertmanager routes by `severity`, see
`pillar/alertmanager.sls`). New publishers: another `extra_publishers` entry (user, bcrypt hash,
token, topics) in `pillar/ntfy.sls` — never share the Alertmanager token.

## OpenBao

| Path | Keys |
|---|---|
| `ntfy/admin` | `password` (for logging in, not read by pillar), `password_hash` (bcrypt) |
| `ntfy/alertmanager` | `password_hash` (bcrypt of a throwaway password — the user never logs in), `token` (`tk_` + 29 chars) |

ntfy only accepts bcrypt hashes (`$2a$`/`$2b$`/`$2y$`, cost ≥ 10) and tokens matching
`^tk_[-_A-Za-z0-9]{29}$`. Create them on the OpenBao VM (`htpasswd` is in `apache2-utils`):

```sh
PW=$(openssl rand -base64 24); bao kv put -mount=homelab ntfy/admin password="$PW" password_hash="$(htpasswd -nbBC 10 '' "$PW" | tr -d ':\n')"; unset PW
PW=$(openssl rand -base64 24); bao kv put -mount=homelab ntfy/alertmanager password_hash="$(htpasswd -nbBC 10 '' "$PW" | tr -d ':\n')" token="tk_$(openssl rand -hex 15 | cut -c1-29)"; unset PW
bao kv get -mount=homelab ntfy/admin; bao kv get -mount=homelab ntfy/alertmanager
```

Rotating the token: new value in `ntfy/alertmanager`, then apply jellyfin (ntfy restarts with
the new token, the old one is deleted) and monitoring (Alertmanager picks it up) — alerts in
between fail to deliver and are retried.

## Manual steps

- Phone: install the ntfy app (Android: F-Droid or Play), add server
  `http://192.168.178.24:8090`, log in as `admin`, subscribe to `alerts-critical` and
  `alerts-warning`. Android: allow the app to ignore battery optimisation (instant delivery
  keeps a connection open). LAN only — no notifications away from home Wi-Fi yet.
- Test after the first apply (from the LAN, token from OpenBao):
  `curl -H "Authorization: Bearer <token>" -d test http://192.168.178.24:8090/alerts-warning`;
  an anonymous `curl -d test …/alerts-warning` must get 403.

## Open

- Reach from outside the LAN: ntfy.sh as `upstream-base-url` (iOS needs it; only message IDs
  go upstream) vs. the tailscale-router VM. Off for now.
- Plain HTTP on the LAN (token and login in clear text) until the reverse proxy item lands.
- `IaC-opentofu`'s `.forgejo/workflows/drift.yml` could publish here too (today its only
  signal is the Forgejo issue) — needs its own publisher user/token.

## Usage

```yaml
# salt/top.sls
'jellyfin':
  - users
  - podman
  - ntfy
```

## Pillar

See `pillar.example.sls`. Real values in `pillar/ntfy.sls`.
