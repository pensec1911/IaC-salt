# salt-master formula

Manages the salt-master's own config so it pulls its state tree and pillar directly from this
repo (gitfs + git_pillar) instead of relying on a manually-copied `/srv/salt`. Generates its own
deploy key, pins GitHub's host key, and writes
`/etc/salt/master.d/{gitfs,git_pillar,auto_accept,pillar_merge}.conf`.

Also owns the master's OpenBao (sdb) auth (`vault.sls` → `/etc/salt/master.d/vault.conf`) — this
is what makes `sdb://...` references in pillar (see `formulas/users`, CLAUDE.md "Secrets in
pillar") resolve to real values instead of erroring.

This is the one formula that isn't fully generic — `map.jinja`'s defaults point at this exact
repo (`pensec1911/IaC-salt`) since that's what a fresh master actually needs to bootstrap
against. Override via `salt-master:lookup` pillar (see `pillar.example.sls`) if the repo is ever
renamed or forked.

## Bootstrap

See the repo root `README.md` for the one-time manual step required before gitfs can take over
(the master has nothing to pull from until it's configured once).

### OpenBao AppRole (manual, one-time)

`vault.sls` can't create its own credentials — an AppRole `secret_id` isn't something Salt can
generate locally the way the gitfs deploy key is. Before applying this formula (or after, it'll
just fail cleanly on the `file.exists` guard until this is done):

1. In OpenBao: create a `salt-master` AppRole role (same pattern as the existing
   `opentofu`/`ansible-deploy` roles) with a read-only policy scoped to the KV-v2 path
   `sdb_kv_path` points at (default `homelab/data/*`).
2. Set `salt-master:lookup:vault_role_id` in pillar (not secret, fine to commit) to that role's
   `role_id`.
3. Generate a `secret_id` for the role and write it to the master at
   `salt-master:lookup:vault_secret_id_file` (default `/etc/salt/vault-secret-id`), root-owned,
   mode `0600`. Never commit this file or its contents.
