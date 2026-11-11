# salt-master formula

Manages the salt-master's own config so it pulls its state tree and pillar directly from this
repo (gitfs + git_pillar) instead of relying on a manually-copied `/srv/salt`. Generates its own
deploy key, pins the git servers' host keys (GitHub, Forgejo), and writes
`/etc/salt/master.d/{gitfs,git_pillar,auto_accept,pillar_merge,reactor,api}.conf`. Runs salt-api
for webhooks (`api.sls`).

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

## Reactor: deploy on push

With `push_deploy`, `gitfs.conf` sets `fileserver_events: True`. The master then fires
`salt/fileserver/gitfs/update` after every gitfs fetch (every `gitfs_update_interval`, 60 s).
`reactor/gitfs-update.sls` acts only on `changed: true`, i.e. new commits on `main`, and starts
`salt-run state.orchestrate orch.push` (`formulas/orch`). That is `orch.rollout` restricted to
the minions whose drift check may repair right now: homepage, monitoring, forgejo and salt-master at any
hour; arrstack and jellyfin only 03:00–06:00 (otherwise the nightly enforce picks the push up);
wazuh never (manual apply). Dry run on all first, then one at a time, stops at the first failure.

So a push reaches the enforce minions about a minute later, not up to an hour later. Any push
to `main` counts, docs-only too (it ends in a 0-change highstate). The event comes from the
master's own maintenance process, so no webhook or minion can trigger it. Results:
`salt-run jobs.list_jobs search_function=runner.state.orchestrate`, or watch
`salt-run state.event pretty=True` during a push. Turn it off with `push_deploy: False`.

## salt-api

`api.sls` installs `salt-api`, pinned to the installed salt-master version (it depends on
exactly that version, so the newest one would upgrade the master on the side). It runs
rest_cherrypy on `:8000`, HTTPS only. There is no `external_auth`, so `/login` and `/run`
accept nobody. Only `/hook/<path>` works, without Salt auth (`webhook_disable_auth`). It fires
`salt/netapi/hook/<path>` with `{body, post, headers}`. Tags that aren't mapped in
`reactor.conf` do nothing. Each mapped reactor SLS checks its sender itself.

`/hook/alertmanager` → `reactor/alertmanager-hook.sls`, mapped only when
`api_alertmanager_token` is set. It requires `Authorization: Bearer <token>` (OpenBao
`salt-api/alertmanager`, the same entry Alertmanager sends from, `pillar/alertmanager.sls`).
For each firing alert it runs the drift check (`schedule.run_job drift-check`,
`formulas/salt-minion`) on the minion the alert names. The minion comes from the IP in the
`url` label (ProbeFailed, ipcidr match) or from `instance` (TargetDown, the minion id). It runs
the drift check, not a highstate, so the enforce flag and window still decide: a stopped
container on homepage is started again within minutes, while on arrstack by day the alert only
refreshes the drift metrics. Alertmanager only sends `TargetDown|ProbeFailed`, repeating hourly
while they fire.

`/hook/git` → `reactor/git-hook.sls`, mapped only when `api_git_hmac_secret` is set (OpenBao
`salt-api/forgejo`, key `hmac`, the same secret the Forgejo webhook signs with). It requires
`X-Hub-Signature-256: sha256=<HMAC-SHA256 of the raw body>` and a push to the deployed branch,
then runs `fileserver.update`. The gitfs update event that follows starts the push deploy as
usual (`reactor/gitfs-update.sls`), so a push lands in seconds instead of after the next 60 s
poll. Forgejo trusts the self-signed cert via `forgejo:lookup:extra_ca_certs`.

Test the Alertmanager hook from the master with the token (`sudo grep homelab_alertmanager_token /etc/salt/master.d/api.conf`),
watching `salt-run state.event pretty=True`:

```sh
curl -s --cacert /etc/salt/pki/api/salt-api.crt -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' https://192.168.178.28:8000/hook/alertmanager \
  -d '{"alerts":[{"status":"firing","labels":{"alertname":"TargetDown","instance":"homepage"}}]}'
```

### salt-api TLS (manual, one-time)

The cert is self-signed, and the key never leaves the master. The state only checks that both
files exist and enforces `0640 root:salt` on the key (salt-api runs as `salt`):

```sh
D=/etc/salt/pki/api   # api_tls_dir; the state creates it (0750 root:salt)
sudo install -d -m 0750 -o root -g salt $D
sudo bash -c "umask 027; openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
  -nodes -days 1825 -subj /O=homelab/CN=salt-api \
  -addext subjectAltName=IP:192.168.178.28 -addext basicConstraints=critical,CA:TRUE \
  -keyout $D/salt-api.key -out $D/salt-api.crt"
sudo chown root:salt $D/salt-api.*; sudo chmod 0644 $D/salt-api.crt
sudo cat $D/salt-api.crt   # → pillar/alertmanager.sls tls_config.ca
```

Clients pin this cert (Alertmanager: `tls_config.ca` in `pillar/alertmanager.sls`). Current
one: issued 2026-10-26, expires 2031-10-25. To re-issue, run the same commands, update the PEM
in pillar (`pillar/alertmanager.sls` and `pillar/forgejo.sls`), and restart salt-api. The master isn't backed up, so a rebuilt master needs this
step again.

## Render check for PRs

`render-check.sls` (with `render_check_ci`) installs `files/render-check.py` as
`render_check_script`, the same script `.githooks/pre-push` runs from the pushed tree. It also
installs `render_check_wrapper`, the forced command of the `render-check` user's only SSH key
(`pillar/salt-master.sls`, `restrict,command=…`). The IaC-salt workflow
`.forgejo/workflows/render-check.yml` runs on every PR. It pipes a tar of `formulas/ salt/
pillar/` over SSH, and the wrapper unpacks it into a temp dir and renders every minion. Branch
protection on `main` requires the check, so a PR merged in the UI can't skip it.

- The PR's Jinja is rendered here, as that unprivileged user (`salt-call --local`, sdb stubbed).
  It has no sudo and no read access to the deploy key, `vault.conf` or `api.conf`. Only
  `homelab` repo writers (you, `renovate-bot`) can open PRs that get the secret.
- The checker is the copy from `main`, so a PR that edits `render-check.py` is still judged by
  the current one.
- The key: the private half is only the IaC-salt Actions secret `RENDER_CHECK_SSH_KEY`, the
  public half is in pillar. If it's lost, generate a new pair and replace both.

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
