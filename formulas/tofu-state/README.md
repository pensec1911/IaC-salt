# tofu-state formula

One Postgres container that holds the OpenTofu state of `IaC-opentofu` (`backend "pg"`, schema
`homelab`). Depends on the `podman` formula. Runs on forgejo next to the Actions runner whose
plan/drift jobs read it.

## What it manages

- `tofu-state.config` — `base_dir`, `data_dir` (owner left to the container via `:U`),
  `dump_dir` (0700, for formulas/backup's pg_dump), `secrets_dir` (0700) with `db_password`
  (0444, bound alone). Fails on a blank or unresolved password.
- `tofu-state.container` — `postgres` (alpine image, runs as its own user 70:70), published on
  `postgres_port` (5432) to the LAN.

## Access and security

Clients: the user's machine (`tofu apply`) and Forgejo Actions jobs (`plan`, nightly drift
check), both over the LAN — that's why the port is published, unlike netbox/patchmon's
postgres. Auth is scram-sha-256 (the image's `pg_hba` default once a password is set), no TLS.
Acceptable because OpenTofu encrypts the state **client-side** (`encryption` block, passphrase
in OpenBao `tofu-state/encryption`): the DB, its dumps and the wire only carry ciphertext. The
password only protects against someone deleting or locking the state.

## OpenBao

`tofu-state/postgres`, key `password` — create before the first apply:
`bao kv put -mount=homelab tofu-state/postgres password=<random>`. Read once, on first init of
`data_dir` (`POSTGRES_PASSWORD_FILE`); rotating later needs
`podman exec tofu-state-postgres psql -U tofu -c "ALTER ROLE tofu PASSWORD '…'"` in addition, plus
the new value in `IaC-opentofu`'s `backend.hcl` and the `PG_CONN_STR` Actions secret.

The state passphrase (`tofu-state/encryption`) is not used by Salt — only by Tofu (README
"State" in IaC-opentofu). Without it the state is unreadable.

## Backup

`pillar/backup.sls` (forgejo): pre-run `pg_dump -Fc` to `dump_dir`, `data_dir` and `secrets_dir`
excluded. Restore: the weekly restore test checks the dump; a real restore is `pg_restore` into a
fresh container. Note that the state of the `forgejo` VM itself lives here — losing forgejo
means restoring this dump from the NAS before running `tofu` again.

## Pillar

See `pillar.example.sls`. Real values live in `pillar/tofu-state.sls`.
