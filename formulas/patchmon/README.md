# patchmon formula

Runs the [PatchMon](https://patchmon.net) server (`ghcr.io/patchmon/patchmon-server`): a
patch/package inventory of every minion, fed by `formulas/patchmon-agent`. Depends on the
`podman` formula. Next to unattended-upgrades (which still does the actual nightly patching),
it shows per host and per package what's outstanding, security updates, reboot need, history.

## Security model — read first

The agent runs as root and keeps a WebSocket open to this server. From the UI the server can
**start patch runs** (`apt-get upgrade`) and **push agent updates** to every enrolled host.
Whoever owns this server (or a PatchMon admin login) can therefore run package installs as root
on every minion. That's why it sits on forgejo, which as the Salt deploy source is already
root-equivalent for the fleet — PatchMon adds no new host of that kind.

Kept closed on purpose:
- **Agent auto-update off** (Settings → Agent Updates, manual, first run). The agent binary is
  pinned and sha256-checked by Salt (`formulas/patchmon-agent`); an update from the server would
  be reverted on the next highstate anyway.
- **SSH/RDP proxy off** on every agent — only settable in the agent's local `config.yml`, never
  from the server; Salt writes them `false`. No guacd sidecar here.
- Patch runs from the UI stay possible but are only started by a click.
- Admin login: strong password + TOTP (first run).

## What it manages

- `patchmon.config` — a check that `cors_origin` and the four secrets are set (fails on blank or
  unresolved `sdb://`); `secrets_dir` (`/opt/patchmon/secrets`, 0700 root) with
  `patchmon.env` (JWT/session/AI keys, `DATABASE_URL`) and `db_password`, each bound read-only
  into its container — the server loads it via `ENV_FILE`, postgres via
  `POSTGRES_PASSWORD_FILE`. Never in container env, state diffs or `podman inspect`. Dirs for
  postgres, valkey and the backup dump.
- `patchmon.container` — the private Podman network (`network` macro, DNS by container name) `patchmon` and on it:
  - `patchmon-postgres` (`postgres:17.x-alpine`, the major upstream ships),
  - `patchmon-valkey` (instead of upstream's redis; AOF on, no password, no published port),
  - `patchmon` — UI + API + agent WebSocket on `http_port` (3001 → 3000). Runs its DB
    migrations on start. A changed env file restarts it.

## OpenBao (manual, once — before the first apply)

```sh
bao kv put -mount=homelab patchmon/server \
  jwt_secret="$(openssl rand -hex 64)" \
  session_secret="$(openssl rand -hex 64)" \
  ai_encryption_key="$(openssl rand -hex 64)" \
  db_password="$(openssl rand -hex 32)"
```

- `db_password` is only applied when postgres initialises an empty `postgres_dir`. Changing it
  later: `ALTER USER patchmon_user PASSWORD '…'` first, then OpenBao, then highstate.
- `ai_encryption_key` encrypts stored settings secrets; changing it makes them unreadable.
- `jwt_secret`/`session_secret`: changing them logs everyone out.

## First run (manual, once)

1. Open `http://192.168.178.29:3001` — the setup wizard creates the first (super)admin. Store
   it in OpenBao (`homelab/patchmon/admin`, `username`/`password`); turn on TOTP for it.
2. Settings → General → **Server URL** = `http://192.168.178.29:3001` (the URL agents connect
   back to; stored in the DB, not in env).
3. Settings → Agent Updates → **auto-update off**.
4. Auto-enrollment token for the agents: `formulas/patchmon-agent` README "Enrolment".

## Backup / restore

`pillar/backup.sls` (forgejo): `/opt/patchmon` without `postgres/`, `valkey/` and `secrets/`,
plus a `pg_dump -Fc` before each run (`/opt/patchmon/dump/patchmon.pgdump`). Restore like
netbox (formulas/netbox README), with `patchmon` / `patchmon-postgres` / `patchmon_user` /
`patchmon_db`.

## Upgrades

Renovate tracks the server, postgres and valkey tags. **Bump the agent with the server**:
`formulas/patchmon-agent` pins `version` + `sha256` by hand (GitHub release assets), and
agent ≠ server version shows as outdated in the UI. A postgres major (17 → 18) needs a
dump/restore into a fresh `postgres_dir` — do it by hand.

## Not managed

- Users, host groups, patch policies, notification targets — UI, in the DB.
- TLS — plain HTTP in the LAN like the other UIs (agents too: no secrets beyond their own
  API key cross the wire, but it is cleartext on the LAN).
