# netbox formula

Runs [NetBox](https://netbox.dev) (IPAM/DCIM) from the upstream
[netbox-docker](https://github.com/netbox-community/netbox-docker) image as four Docker
containers. Depends on the `docker` formula; nothing on the host besides the dirs under
`/opt/netbox`. It's the inventory database for the homelab — this formula only runs it;
what goes in, and whether Salt/Tofu read from it, is the roadmap item "NetBox as source of
truth".

## What it manages

- `netbox.config`
  - a check that the three secrets are set (fails on blank or unresolved `sdb://`),
  - `secrets_dir` (`/opt/netbox/secrets`, 0750 root:root) with one 0440 file per secret —
    bound to `/run/secrets`, where the image's `configuration.py` and
    `POSTGRES_PASSWORD_FILE` read them. Not in the containers' env, so not in `docker inspect`,
  - `media_dir` (uploads/images, owned by the image's `netbox` user 999:0), `postgres_dir`,
    `valkey_dir` (owned by the containers' entrypoints), `dump_dir` (root, 0700).
- `netbox.container` — the private docker network `netbox` and on it:
  - `netbox-postgres` (`postgres:18.x-alpine`, data in `postgres_dir`),
  - `netbox-valkey` (`valkey:9.x-alpine`, AOF on; task queue in DB 0, cache in DB 1 — one
    instance instead of upstream's two, and without a password: no published port, nothing
    else on the network),
  - `netbox` — web UI/API on `http_port` (8000 → Granian 8080). Its entrypoint runs the DB
    migrations on every start (first start on forgejo: ~6 min before the UI answers; the worker
    crash-loops until they are done),
  - `netbox-worker` — `rqworker` for background jobs, webhooks and NetBox's housekeeping
    system job (no separate housekeeping container/cron any more).
- All NetBox settings come from env: the defaults in `map.jinja` `config` plus pillar
  `netbox:lookup:config` (any variable the image's
  [configuration.py](https://github.com/netbox-community/netbox-docker/blob/release/configuration/configuration.py)
  reads). A changed secret file restarts netbox + worker.

## Usage

```yaml
# salt/top.sls
'forgejo':
  - users
  - docker
  - netbox
  - backup
```

## Pillar

See `pillar.example.sls`. Real values: `pillar/netbox.sls` (only the sdb references).

## OpenBao (manual, once — before the first apply)

```sh
bao kv put -mount=homelab netbox/app \
  secret_key="$(openssl rand -base64 48 | tr -d '\n')" \
  db_password="$(openssl rand -hex 24)" \
  api_token_pepper="$(openssl rand -base64 48 | tr -d '\n')"
```

`secret_key` and `api_token_pepper` must be ≥ 50 chars (64 here). Without the entry the
formula fails with `netbox:lookup secrets empty or unresolved`.

- `db_password` is only applied when postgres initialises an empty `postgres_dir`. Changing it
  later: `ALTER USER netbox PASSWORD '…'` in the DB first, then OpenBao, then highstate.
- `api_token_pepper` hashes v2 API tokens: changing it invalidates every v2 token.
- `secret_key`: changing it logs everyone out; nothing persistent depends on it.

## First run (manual, once)

The image is started with `SKIP_SUPERUSER=true` (no admin password in env). After the first
apply, once `http://192.168.178.29:8000` shows the login page:

```sh
ssh -i ~/.ssh/homelab debian@192.168.178.29 \
  sudo docker exec -it netbox /opt/netbox/netbox/manage.py createsuperuser
```

Store the account in OpenBao (`homelab/netbox/admin`, keys `username`/`password`). API tokens
for automation (Salt ext_pillar, Tofu provider): create them in the UI under that user (or a
dedicated one) and put them in OpenBao — never in pillar as a literal.

## Backup / restore

`pillar/backup.sls` (forgejo): `/opt/netbox` without `postgres/`, `valkey/` and `secrets/`, plus
a `pg_dump -Fc` of the DB taken by `formulas/backup` right before each run
(`/opt/netbox/dump/netbox.pgdump`, `dumps` there). The weekly restore test checks the dump's
header. Restore on a fresh/emptied `postgres_dir`:

```sh
sudo -i
set -a; . /etc/restic/env; set +a
restic restore latest --target / --include /opt/netbox/media --include /opt/netbox/dump
docker stop netbox netbox-worker
docker exec -i netbox-postgres pg_restore -U netbox -d netbox --clean --if-exists --no-owner \
  < /opt/netbox/dump/netbox.pgdump
docker start netbox netbox-worker
```

(On a brand-new VM: apply the highstate first so postgres creates the empty DB, then the
above.)

## Upgrades

Renovate tracks all three tags (rule for the `v<netbox>-<netbox-docker>` scheme in
`renovate.json`). NetBox migrates on start; read the release notes for the minimum version you
can upgrade from. A postgres **major** bump (18 → 19) is not a tag change — it needs a
dump/restore into a fresh `postgres_dir`, so do it by hand.

## Not managed

- Content (sites, prefixes, VMs, IPs) — UI/API, in the DB.
- Superuser and API tokens — manual, above.
- TLS — plain HTTP in the LAN like the other UIs.
