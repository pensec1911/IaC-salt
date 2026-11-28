# healthchecks formula

Runs [Healthchecks](https://healthchecks.io/docs/self_hosted/)
([healthchecks/healthchecks](https://hub.docker.com/r/healthchecks/healthchecks)) as a Podman
container (Quadlet unit via `formulas/podman`) — the dead-man's switch for jobs. Prometheus only
alerts on what it can scrape; here every job pings after each run and a **missing** ping is the
alert, sent to ntfy (`alerts-critical`). Depends on the `podman` and `users` formulas; the
pinging side is `formulas/healthchecks-ping`.

Runs on jellyfin, not monitoring: it must outlive monitoring (it watches Alertmanager's
Watchdog). jellyfin and monitoring share Proxmox node pve02, so a pve02 outage silences both —
an external watcher of this instance (healthchecks.io free tier) is an open follow-up.

## What it manages

- `healthchecks.config` — fails with `healthchecks-config-valid` if `secret_key` is empty or
  unresolved or `site_root` is missing (Django never starts with an empty signing key).
  `/opt/healthchecks/data` (`healthchecks` 975:975): `hc.sqlite` — checks, pings, users,
  integrations.
- `healthchecks.container` — the container, as `healthchecks` (975, mapped 1:1), read-only root,
  gunicorn on 8000 (published on `http_port`). Config is environment only (`map.jinja` `env`);
  `SECRET_KEY` via the 0600 secret env file. Registration closed, no SMTP, `DEBUG=False`,
  `INTEGRATIONS_ALLOW_PRIVATE_IPS=True` (ntfy is on the LAN), 2 gunicorn workers.
  The image's `run.sh` migrates the DB on every start, then runs gunicorn, `sendalerts` and
  `sendreports`.
- `healthchecks.provision` — checks as code, see below. Only with an API key in pillar.

Backed up nightly (`pillar/backup.sls`, container stopped for the ~1 min run;
`provision/` excluded — it only holds the API key and the rendered list).

## Checks as code

Checks are identified by **slug** and pinged as `/ping/<project ping key>/<slug>?create=1`, so
a job's first ping creates its check (defaults: period 1 day, grace 1 h). The real period/grace
come from `healthchecks:lookup:checks` in `pillar/healthchecks.sls`: `provision.sls` upserts that
list via the Management API (`POST /api/v3/checks/`, `unique: ["slug"]`, `channels: "*"` = all
integrations, i.e. ntfy) whenever the list or the API key changed or the last run failed
(stamp in `provision/applied.sha256`). Checks dropped from the list are **not** deleted — remove
them in the UI.

| Slug | Period | Grace |
|---|---|---|
| `alertmanager-watchdog` | 5 min | 5 min |
| `drift-check-<minion>` (every minion) | 1 h | 30 min |
| `backup-<minion>` (backup minions) | cron `0 2 * * *` Europe/Berlin | 1 h |
| `restore-test-<minion>` | cron `0 4 * * 0` Europe/Berlin | 2 h |

A new minion: add it to the lists at the top of `pillar/healthchecks.sls`.

## OpenBao

| Path | Keys | Notes |
|---|---|---|
| `healthchecks/app` | `secret_key` | Django `SECRET_KEY`, generated |
| `healthchecks/project` | `ping_key`, `api_key` | both from the UI (Project Settings), after the first login; optional — without `ping_key` nothing pings, without `api_key` nothing is provisioned |
| `ntfy/healthchecks` | `password_hash`, `token` | ntfy user `healthchecks`, write-only on `alerts-critical` (`pillar/ntfy.sls`); the token is entered in the Healthchecks ntfy integration |

```sh
bao kv put -mount=homelab healthchecks/app secret_key="$(openssl rand -hex 32)"
PW=$(openssl rand -base64 24); bao kv put -mount=homelab ntfy/healthchecks password_hash="$(htpasswd -nbBC 10 '' "$PW" | tr -d ':\n')" token="tk_$(openssl rand -hex 15 | cut -c1-29)"; unset PW
# after the first login (Manual steps 2-3), paste each value + Ctrl-D:
bao kv put -mount=homelab healthchecks/project ping_key=-
bao kv patch -mount=homelab healthchecks/project api_key=-
bao kv get -mount=homelab healthchecks/app; bao kv get -mount=homelab healthchecks/project; bao kv get -mount=homelab ntfy/healthchecks
```

## Login

Behind Caddy with Authentik forward auth (route `healthchecks`, `auth: forward`).
`REMOTE_USER_HEADER: HTTP_X_AUTHENTIK_EMAIL` (`pillar/healthchecks.sls` `env`) logs in the
Healthchecks user whose e-mail equals the Authentik user's, and creates a new (empty) user if
there's none — so the account's e-mail must match the Authentik one (Account → Email, or
`manage.py shell`). The header replaces the password login completely: on
`http://192.168.178.24:8000` directly nobody can log in (pings and the API keep working).
Break-glass if Authentik is down: drop `REMOTE_USER_HEADER` from the pillar and apply jellyfin.

## Manual steps

1. After the first apply on jellyfin, create the superuser (no SMTP, so no signup/reset mail):
   `podman exec -it healthchecks /opt/healthchecks/manage.py createsuperuser` — e-mail address
   is the login name. Keep the password in your password manager.
2. Log in at `http://192.168.178.24:8000`, open the default project → **Settings**:
   - **Ping key** → *Create*; put it in OpenBao `healthchecks/project ping_key`.
   - **API Access** → *Create API key* (read-write, not read-only); `healthchecks/project api_key`.
3. **Integrations** → **ntfy** → *Add*:
   - Topic: `alerts-critical`, Server: `http://192.168.178.24:8090`
   - Access token: OpenBao `ntfy/healthchecks token`
   - Priority when down: *high*, when up: *default*
   - Save (new integrations are assigned to all existing checks; provisioning assigns `*` too).
   *Send test notification* must arrive on the phone.
4. Apply jellyfin (ntfy gets the `healthchecks` user, checks are provisioned), then monitoring
   (Watchdog rule + Alertmanager route) and all other minions (ping helper + unit lines) — or
   wait for their self-repair. `alertmanager-watchdog` turns green within ~2 min.
5. Optional: Account → set a time zone; **Settings** → project name.

Nothing alerts until a check got its first ping (state "new") — a minion that never pings
(e.g. wazuh while off) stays grey, not red.

## Open

- External watcher for this instance itself (it shares pve02 with monitoring): healthchecks.io
  free tier pinged by a tiny job here, or an OPNsense/uptime monitor.
- Renovate, Trivy and Tofu drift (Forgejo Actions in other repos) could ping too — each needs
  the ping key as a CI secret.
- Plain HTTP on the LAN (login and ping key in clear text) until the reverse proxy item lands.

## Usage

```yaml
# salt/top.sls
'jellyfin':
  - users
  - podman
  - healthchecks
```

## Pillar

See `pillar.example.sls`. Real values in `pillar/healthchecks.sls`.
