# users formula

Generic, pillar-driven user/group management. Nothing here is service- or minion-specific — every
account it manages comes entirely from `pillar:users:accounts`.

## What it manages

Loops over `users:accounts` (a list of dicts) and emits one `group.present` + `user.present` pair
per entry, with fixed, predictable state IDs: `group-<name>` and `user-<name>`. Optional
`ssh_authorized_keys` on an entry get `ssh_auth.present` states (`ssh-auth-<name>-<n>`).

A service formula that needs a dedicated user doesn't create one itself — it appends to
`users:accounts` from its own `pillar/<name>.sls` and declares `require: - user: user-<name>` in
its own state. See `formulas/homepage`'s `homepage` account in `pillar/homepage.sls` for the
pattern once that's wired up, or `pillar.example.sls` here for the schema.

`pillar/GLOBAL.sls` additionally adds one self-named login account per minion (`grains.id`) with
sudo + an SSH key, since every minion needs a personal login user named after itself.

This only merges correctly across multiple pillar sls files (GLOBAL + per-service) if
`pillar_merge_lists: True` is set in the master config — see `formulas/salt-master/config.sls`,
which manages this. Without it, Salt overwrites `users:accounts` per included pillar sls instead
of merging, and only the last one would survive.

## Usage

Add `users` to a minion's entry in `salt/top.sls`, before any formula that requires an account it
creates:

```yaml
'some-minion':
  - users
  - docker
  - some-service
```

## Pillar

See `pillar.example.sls` for the full schema.

### Passwords come from OpenBao, not plaintext

`password` on an account is a `sdb://` reference (see CLAUDE.md "Secrets in pillar"), resolved by
the master at render time — never a literal value in a pillar file. It must point to an
**already-hashed** value (`sha512-crypt`, the same format `/etc/shadow` stores), not a plaintext
password.

This depends on `formulas/salt-master/vault.sls` (the master's OpenBao/sdb auth) being applied,
**and** the actual secret existing in OpenBao at the referenced KV path/key — this formula only
consumes the reference, it doesn't create the secret. Until both of those are true,
`state.apply users` will fail when Salt tries to resolve the `sdb://...` value.

Right now every minion's self-named account (`pillar/GLOBAL.sls`) points at a single shared
secret, `sdb://osvault/homelab/data/users/shared?password` — one password for every account, on
purpose, to avoid provisioning ten separate OpenBao secrets up front. Switch to a per-minion
secret later by changing that path to include `{{ grains['id'] }}` (e.g.
`sdb://osvault/homelab/data/users/{{ grains['id'] }}?password`) once per-minion passwords are
actually wanted — it's a one-line pillar change, no formula change needed.

Note the sdb `vault` driver has no path-prefix config option — the KV mount/base
(`homelab/data`) must be spelled out in full in every `sdb://` reference, not just implied by the
`osvault` profile. See `formulas/salt-master/files/vault.conf.j2`.
