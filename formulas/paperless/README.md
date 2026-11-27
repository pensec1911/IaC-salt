# paperless formula

Runs [Paperless-ngx](https://docs.paperless-ngx.com) (document management: OCR, auto-tagging,
full-text search) as three Podman containers on a private network: `paperless` (web UI,
consumer, OCR and task worker in one image), `paperless-postgres` and `paperless-valkey`
(Celery broker). Depends on `podman`, `users` and — when the documents live on the NAS —
`nfs-mount`. Runs on `docs` (.21), reached as `https://docs.home.<domain>` through edge.

## What it manages

- `paperless.config`
  - a check that `secret_key`, `db_password`, `url` (and with OIDC `oidc_client_secret`) are
    set — fails on blank or unresolved `sdb://`,
  - `data_dir` (`/opt/paperless/data`: search index, classifier model, logs; owned by
    `uid:gid` 979), `postgres_dir` and `valkey_dir` (handed to the containers by `:U`),
    `dump_dir` (root, 0700),
  - `media_dir` and `consume_dir` — on the NFS share created as 979 via `setpriv` (the NAS
    squashes root), locally a plain directory,
  - `secrets_dir` (0700 root) with one 0444 file per secret, without trailing newline, bound
    to `/run/secrets` and read through upstream's `PAPERLESS_<X>_FILE` support. Not in env,
    so not in `podman inspect`. With OIDC also `socialaccount_providers` (the provider JSON
    incl. the client secret).
- `paperless.container` — network `paperless` and on it:
  - `paperless-postgres` (`postgres:18.x-alpine`), `paperless-valkey` (`valkey:9.x-alpine`,
    AOF on, no password — no published port, nothing else on the network),
  - `paperless` on `http_port` (8000), started directly as `979:979` (upstream's rootless
    mode: s6 skips its UID remapping, `USERMAP_UID/GID` don't apply), mapped 1:1, no
    capabilities, writable root (s6 needs `/run`). Its entrypoint migrates the DB on start.
- All further settings: `paperless:lookup:config` (any `PAPERLESS_*` variable, merged last).

## Pillar

See `pillar.example.sls`. Real values: `pillar/paperless.sls`.

## NAS (manual, once — before the first apply)

TrueNAS: child dataset `pool01/documents/paperless`, ACL type POSIX, owner `979:979`, mode
**751**; NFS share on exactly that path, host `192.168.178.21` only, maproot/mapall empty. Then
`nfs-mount` mounts it at `/mnt/paperless`.

- **Own share for the child dataset**, not one on `documents`: a child dataset is its own
  filesystem, and through the parent's export the client only sees the empty directory
  underneath (root:root 755 — 2026-11-27). Check with `cat /etc/exports` on TrueNAS.
- **751, not 770**: Podman runs as root and `statfs`es the bind sources before the container
  starts; root is squashed to nobody, so without the "other" x bit the unit fails with
  `statfs /mnt/paperless/media: permission denied`. x only — nobody can't list it. 979 can
  set it itself from docs: `setpriv --reuid=979 --regid=979 --clear-groups chmod 751 /mnt/paperless`.
- Mounted while the NAS was still booting (child dataset not yet mounted there), the client can
  stick to the empty parent directory: `umount -l /mnt/paperless; mount /mnt/paperless`.

## OpenBao (manual, once — before the first apply)

```sh
bao kv put -mount=homelab paperless/app \
  secret_key="$(openssl rand -base64 48 | tr -d '\n')" \
  db_password="$(openssl rand -hex 24)"
bao kv put -mount=homelab authentik/oidc-paperless \
  client_secret="$(openssl rand -hex 32)"
```

`authentik/oidc-paperless` is read by edge too (provider `paperless`, pillar/authentik.sls) —
without it edge's highstate fails as well, so create both before merging.

- `db_password` only takes effect when postgres initialises an empty `postgres_dir`. Later:
  `ALTER USER paperless PASSWORD '…'` first, then OpenBao, then highstate.
- `secret_key`: changing it logs everyone out and invalidates sessions.

## First run (manual, once)

After the first apply, once `https://docs.home.<domain>` shows the login page (first start
migrates the DB, a few minutes):

```sh
ssh -i ~/.ssh/homelab debian@192.168.178.21 \
  sudo podman exec -it paperless python3 manage.py createsuperuser
```

Store it in OpenBao (`paperless/admin`, `username`/`password`). This local account is what the
phone apps (Paperless Mobile, Swift Paperless) log in with — or a token from the UI (profile →
API auth token). The phone reaches `https://docs.home.<domain>` over the tailnet.

Then in the UI: correspondents, document types, tags and their matching rules; custom fields
(`amount`, `due date`, `interval`); a storage path like
`{{ document_type }}/{{ correspondent }}/{{ created_year }}/{{ title }}`; saved views
("Subscriptions", "Expenses <year>"). All of it lives in the DB (backed up), not in Salt.

## SSO

"Log in with Authentik" (OIDC provider `paperless`, only the admin group may use it). The first
SSO login creates an unprivileged user; make it superuser once as the local admin (Admin →
Users) or:

```sh
sudo podman exec -it paperless python3 manage.py shell \
  -c "from django.contrib.auth.models import User; u=User.objects.get(username='akadmin'); u.is_superuser=u.is_staff=True; u.save()"
```

The local login stays (the apps need it). No forward auth in front (edge route `docs`, `auth:
oidc`): the apps couldn't pass it.

## Backup / restore

`pillar/backup.sls` (docs): `/opt/paperless` without `postgres/`, `valkey/`, `secrets/`,
`data/log` and the celery beat schedule, plus a `pg_dump -Fc` before each run
(`/opt/paperless/dump/paperless.pgdump`). The documents themselves (`media/`) are on the NAS
dataset — covered by TrueNAS snapshots, not by restic (the restic repo is on the same pool;
the offsite copy is roadmap). Restore on an emptied `postgres_dir`:

```sh
sudo -i
set -a; . /etc/restic/env; set +a
restic restore latest --target / --include /opt/paperless/data --include /opt/paperless/dump
systemctl stop paperless
podman exec -i paperless-postgres pg_restore -U paperless -d paperless --clean --if-exists --no-owner \
  < /opt/paperless/dump/paperless.pgdump
systemctl start paperless
```

Portable full export (documents + metadata, version-bound — imports only into the same
Paperless version): `podman exec paperless document_exporter ../export -z` (needs an `export`
bind; not set up).

## Upgrades

Renovate tracks all three tags. Paperless migrates on start; read the release notes (v3.5.0
changed `PAPERLESS_ALLOWED_HOSTS` handling). A postgres **major** bump needs a dump/restore
into a fresh `postgres_dir`, by hand.

## Not managed

- Mail import (IMAP accounts, mail rules), Gotenberg/Tika — roadmap "Later".
- Superuser, tags, rules, storage paths — UI, in the DB.
- Extra OCR languages beyond the bundled `eng deu fra ita spa`: `PAPERLESS_OCR_LANGUAGES` would
  apt-install at start, which fails as non-root.
