# salt-master formula

Manages the salt-master's own config so it pulls its state tree and pillar directly from this
repo (gitfs + git_pillar) instead of relying on a manually-copied `/srv/salt`. Generates its own
deploy key, pins GitHub's host key, and writes
`/etc/salt/master.d/{gitfs,git_pillar,auto_accept,pillar_merge,reactor}.conf`.

Also owns the master's OpenBao (sdb) auth (`vault.sls` → `/etc/salt/master.d/vault.conf`) — this
is what makes `sdb://...` references in pillar (see `formulas/users`, .claude/docs/secrets.md) resolve to real values instead of erroring.

This is the one formula that isn't fully generic — `map.jinja`'s defaults point at this exact
repo (`pensec1911/IaC-salt`) since that's what a fresh master actually needs to bootstrap
against. Override via `salt-master:lookup` pillar (see `pillar.example.sls`) if the repo is ever
renamed or forked.

## Reactor: highstate on minion start

`reactor.conf` maps `salt/minion/*/start` to `reactor/minion-start.sls`, which runs a full
`state.apply` (with `queue=True`) on the minion that started. A VM fresh from Tofu or a reboot
converges without anyone running `state.apply`. The reactor SLS is served over gitfs like
everything else, so changing it needs no master restart — changing `reactor.conf` does (the
`watch_in` handles that). Watch it work: `salt-run state.event pretty=True` on the master, then
restart `salt-minion` somewhere.

Verified on full VM reboots of jellyfin and arrstack (2026-10-18): NFS mounts are up when
salt-minion starts, the highstate queues behind the start-time drift check and converges with
0 changes (arrstack: VPN reconnects, forwarded port re-synced to qBittorrent).

Disable with `salt-master:lookup:highstate_on_start: False`.

## Reactor: refresh mine consumers

`node-exporter`/`cadvisor` fire `homelab/mine/updated` when their mine conf is (re)written —
a new VM, or a formula newly added to one. Not on reboots or unchanged runs. `reactor.conf` maps
that tag to `reactor/mine-updated.sls`, which runs a full `state.apply` (`queue=True`) on
`mine_consumers` (pillar: `monitoring`), so Prometheus scrapes a new VM without a manual run.

The consumer list is written into `reactor.conf` as `homelab_mine_consumers` (a custom master
option the reactor SLS reads via `opts`) — the event only says "refresh", a minion can't choose
the target. Empty `mine_consumers` drops the mapping.

## Reactor: restart stopped services

A minion's service beacon (`formulas/salt-minion`, "Beacons") fires
`salt/beacon/<id>/service/<name>` when a watched service has been down for a while.
`reactor.conf` maps that to `reactor/beacon-service.sls`, which runs `service.start <name>` on
that minion — only for `running: False` and only for services in `beacon_restart_services`
(pillar: `docker`), written into `reactor.conf` as `homelab_beacon_restart_services`. No
highstate: it must stay harmless on arrstack/jellyfin at any hour (they only self-repair at night).

The master doesn't verify the `id` inside beacon events (unlike `salt/minion/<id>/start`), so a
minion could name another one — worst case a whitelisted service gets started there. Empty
`beacon_restart_services` drops the mapping.

## Bootstrap

See the repo root `README.md` for the one-time manual step required before gitfs can take over
(the master has nothing to pull from until it's configured once).

### OpenBao AppRole (manual, one-time)

`vault.sls` can't create its own credentials — an AppRole `secret_id` isn't something Salt can
generate locally the way the gitfs deploy key is. Before applying this formula (or after, it'll
just fail cleanly on the `file.exists` guard until this is done):

1. In OpenBao: create a `salt-master` AppRole role (same pattern as the existing
   `opentofu`/`ansible-deploy` roles). KV read alone is not enough — the policy needs four paths:

   ```hcl
   path "homelab/data/*" {
     capabilities = ["read"]
   }
   path "homelab/metadata/*" {
     capabilities = ["list", "read"]
   }
   # Salt queries the mount to detect the KV version before every read.
   path "sys/internal/ui/mounts/*" {
     capabilities = ["read"]
   }
   # saltext.vault issues a child token for every minion context, and pillar
   # rendering counts as one. Without this: "permission denied" on any read.
   path "auth/token/create" {
     capabilities = ["create", "update"]
   }
   path "auth/token/create/*" {
     capabilities = ["create", "update"]
   }
   ```

   The policy name must also appear in `salt-master:lookup:vault_policies` (default
   `salt-master-read`). OpenBao only lets a token mint child tokens with policies it already
   holds, so a mismatch fails as `child policies must be subset of parent`.
2. Set `salt-master:lookup:vault_role_id` in pillar (not secret, fine to commit) to that role's
   `role_id`.
3. Generate a `secret_id` for the role and write it to the master at
   `salt-master:lookup:vault_secret_id_file` (default `/etc/salt/vault-secret-id`). Never commit
   this file or its contents.

   Write it with no trailing newline, or the newline becomes part of the credential and AppRole
   auth fails with nothing in the error pointing at whitespace:

   ```sh
   sudo bash -c 'umask 077; printf %s "<secret_id>" > /etc/salt/vault-secret-id'
   sudo chown root:salt /etc/salt/vault-secret-id
   sudo chmod 640 /etc/salt/vault-secret-id
   ```

   `root:salt` with mode `0640`, **not** root-only `0600`: the salt-master daemon runs as `salt`
   (see `user:` in `/etc/salt/master`) and has to read this file itself. `vault.sls` asserts these
   permissions on every apply, so a hand-placed `0600` file gets corrected — but the first apply
   needs the file to exist at all.
