# forgejo formula

Runs [Forgejo](https://forgejo.org) (`data.forgejo.org/forgejo/forgejo`, rootless image, LTS
line) as a Docker container with SQLite. Depends on the `docker` and `users` formulas — this
formula only handles the container and its local dirs.

## What it manages

- `forgejo.config` — `data_dir` (repos, SQLite DB, attachments) and `config_dir` (`app.ini`),
  default `/opt/forgejo/{data,config}`, owned by the pinned `git` account (972:972).
- `forgejo.container` — the container, run as that account (docker `user:`), publishing the web
  UI on `http_port` (3000) and git-over-SSH on `ssh_port` (2222; Forgejo's built-in SSH server,
  so the host's port 22 stays with sshd).
- `app.ini` settings from `forgejo:lookup:app_ini`, passed as `FORGEJO__<section>__<KEY>` env
  vars. The image writes them into `app.ini` on every start, so pillar wins over edits in the UI
  or the file for those keys; everything else in `app.ini` stays as Forgejo wrote it.

## Usage

```yaml
# salt/top.sls
'forgejo':
  - users
  - docker
  - forgejo
```

## Pillar

See `pillar.example.sls`. Real values live in `pillar/forgejo.sls`. Nothing in pillar is
secret.

## First run (manual, once)

Open `http://<host>:3000`. The install wizard is pre-filled from the env (SQLite, domain, ports)
— keep those values. Create the admin account there and store its password in OpenBao
(`homelab/forgejo/admin`, keys `username`/`password`). The wizard generates
`SECRET_KEY`/`INTERNAL_TOKEN`/JWT secrets into `config_dir/app.ini` and sets `INSTALL_LOCK`;
they are never in pillar or git, and come back with a restore of `config_dir` (backup).

Losing `app.ini` without a backup means: 2FA secrets and encrypted settings (push-mirror
credentials) are unreadable — restore it, don't re-run the wizard against the old DB.

## Not managed

- Users, orgs, repos, mirrors, deploy keys, webhooks — UI/API, persisted in the DB.
- TLS — plain HTTP in the LAN like the other UIs.
