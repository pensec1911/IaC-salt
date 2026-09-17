# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

SaltStack state tree for the VMs provisioned by `IaC-opentofu` (sibling repo). Tofu creates each
VM, installs `salt-minion` (and `salt-master` on the one VM that needs it) via cloud-init, and
points every minion at the master. This repo owns everything after that: what actually gets
configured on each box. There is no build/test/lint tooling — this is pure Salt state/pillar YAML
and Jinja, applied by the Salt master itself.

## Layout

```
formulas/   # state logic — one directory per formula (docker, homepage, salt-master, ...),
            # each self-contained and pillar-driven: map.jinja, install/config/service.sls,
            # pillar.example.sls, README.md. Nothing in here is environment-specific.
salt/       # environment glue — just top.sls, mapping minion IDs to formulas
pillar/     # pillar tree — actual per-minion data, served via git_pillar, root "pillar"
```

`formulas/` and `salt/` are two different roots of the *same* git remote, merged by gitfs into one
flat fileserver namespace — so `salt://docker/...` and `include: - docker` both resolve regardless
of which directory `docker` physically lives in. This keeps reusable formula code separate from
"which minion runs what," without needing a separate repo per formula.

## Network context

No VLAN segmentation applies to Salt-managed minions currently — everything lands on one flat
network for now. VLAN-aware design happens at the OpenTofu/OPNsense layer (sibling repos), not
here. **Don't introduce VLAN-, subnet-, or firewall-aware logic into states or pillar** until this
changes; keep formulas network-topology-agnostic. If/when segmentation is introduced, expect it to
show up as pillar data (e.g. an interface/IP override in a minion's pillar file), not as anything
formula authors need to special-case.

## Established patterns

- **Generic `users` formula**: service formulas that need a service user/group don't duplicate
  user-creation logic. They `require`/`include` a shared `users` formula and pass the
  user(s)/group(s) they need via pillar, the same way any other formula consumes `map.jinja`
  defaults. When adding a new service that needs a dedicated user, wire it through this formula
  rather than adding `user.present` states locally.

  **Design**: `formulas/users/init.sls` loops over `pillar:users:accounts` (a list of
  `{name, uid?, gid?, group?, home?, shell?, system?, sudo?, password?, ssh_authorized_keys?}`
  dicts) and emits one `group.present` + `user.present` pair per entry, with fixed, predictable
  state IDs: `group-<name>` and `user-<name>`. A service formula that needs one of these declares
  `require: - user: user-<name>` — it never creates the user itself, only references it.
  `uid`/`gid` are optional and normally left unset (auto-assigned) — pin them explicitly only when
  a consuming formula's own `map.jinja` needs to know the number too (Docker PUID/PGID env vars, a
  `docker_container.running` `user:` override), since that value has to be known at Jinja render
  time, not discovered after the fact. See `formulas/arrstack`'s `media` account for the pattern,
  and pick numbers that don't collide with well-known reserved uids (e.g. 65534/`nobody`) or the
  1000+ range regular login accounts land in — including the self-named login account this same
  formula creates per minion, below.

  Each service's own `pillar/<name>.sls` appends its required account(s) to `users:accounts`
  rather than one central file listing every user. This only works cleanly with
  `pillar_merge_lists: True` set in the master config — without it, Salt overwrites the list per
  pillar sls instead of merging, and only the last-included formula's users would survive. Set
  this once in master config, then any minion pulling in both `GLOBAL` (common accounts, if any)
  and a service's pillar sls gets the union.

  Example `pillar/homepage.sls` fragment:
  ```yaml
  users:
    accounts:
      - name: homepage
        system: true
        shell: /usr/sbin/nologin
        home: /var/lib/homepage
  ```
  And in `formulas/homepage/init.sls`: `require: - user: user-homepage`.

  Every minion that includes any formula needing a managed user must also include the `users`
  formula itself in `salt/top.sls`, listed before the formulas that require it.
- **NFS mounts are Salt state, not Tofu state**: where a minion needs an NFS mount (e.g. from the
  TrueNAS shares), that's runtime state of the guest and is expressed as a pillar-driven
  `nfs-mount` formula (`mount.mounted` states built from pillar-supplied share paths), not as a
  Proxmox/Tofu resource attribute. Treat any "this VM needs share X mounted at path Y" requirement
  as pillar data for that minion, consumed by the `nfs-mount` formula. Implemented — see
  `formulas/nfs-mount` (the `arrstack` minion's media share, `pillar/nfs-mount.sls`, is the first
  consumer).
- **VPN-sidecar networking (gluetun)**: a formula whose containers all need to share one VPN
  tunnel attaches them to the VPN container's network namespace via
  `network_mode: container:<name>` instead of giving each its own network. This means only the VPN
  container can `port_bindings` — an attached container can't publish ports of its own — and if any
  of those ports need to stay reachable from the LAN despite everything else being VPN-only, the
  VPN container's own firewall (gluetun's `FIREWALL_INPUT_PORTS`) has to explicitly allow them,
  separately from the Docker port publish. See `formulas/arrstack` (gluetun + qBittorrent/Sonarr/
  Radarr/Prowlarr/slskd) for the concrete pattern before building another VPN-sidecar formula.
- **Security-critical bootstrap steps stay manual, not automated-and-hoped-for-correct**: where
  getting something wrong silently on a security-relevant piece (TLS cert generation, an
  auth-plugin init) is worse than not automating it, scope it out of the formula entirely and
  document it as a one-time manual step instead of guessing at exact tool invocations. Same
  category as the gitfs deploy key and the OpenBao AppRole `secret_id` (both already manual). See
  `formulas/wazuh/README.md` ("What this formula deliberately does NOT do") for the fullest
  example: Salt manages packages/service lifecycle/the config values safe to template, but TLS
  cert generation and the indexer security-plugin init are explicit manual steps, because I don't
  have confidence in the exact current tool invocation and this isn't something to guess at.
- **Patching, not replacing, a package's shipped config**: a native package (unlike this repo's
  Docker-based formulas) often ships substantial default config of its own (Wazuh's default
  `ossec.conf` ruleset/decoders, for instance) that a full Jinja-template overwrite would silently
  drop. Where only specific values need to be pillar-driven, patch them into the existing file with
  `file.blockreplace` (marker-delimited region) instead of `file.managed` wholesale replacement.
  See `formulas/wazuh` and `formulas/wazuh-agent` (`ossec.conf`'s `<indexer>`/`<auth>`/`<client>`/
  `<enrollment>` blocks) — `opensearch.yml`/`opensearch_dashboards.yml` in the same formula, by
  contrast, are small and self-contained enough that a full template is safe there.

## Formula conventions

Every formula follows the same split-file pattern (see `formulas/docker` or `formulas/homepage`
as reference):

- `map.jinja` — defines a dict of defaults, then overlays pillar via
  `salt['pillar.get']('<formula>:lookup', default=defaults, merge=True)`. This is the *only* place
  defaults live; other `.sls` files import from it (`{% from "<formula>/map.jinja" import <formula> with context %}`) and never hardcode values.
- `init.sls` — just an `include:` list wiring together the formula's other `.sls` files (e.g.
  `install.sls`, `config.sls`, `service.sls`/`container.sls`).
- `pillar.example.sls` — documents the pillar schema for the formula (defaults + what's required
  in practice); not consumed directly, just a reference for writing real pillar data.
- `README.md` — what the formula manages, its usage in `salt/top.sls`, and its pillar.

A formula that depends on another (e.g. anything running containers depends on `docker`) declares
it via `require: - sls: docker` in its state, and the dependency must also be listed first in
`salt/top.sls` for that minion. Don't duplicate another formula's setup logic — require it
instead.

## Targeting and pillar wiring

- `salt/top.sls` matches on **minion ID**, not grains — every VM maps 1:1 to a single role (the
  Tofu VM `name`, which cloud-init sets as the hostname/minion ID). Don't add grain-matching
  indirection until a role actually needs to apply to more than one minion.
- `pillar/top.sls` mirrors this: `'*': - GLOBAL` plus one entry per minion that needs pillar data,
  matching the same minion ID used in `salt/top.sls`.
- Real per-service config (e.g. what shows on the homepage dashboard) lives in `pillar/<name>.sls`
  — edit that, not anything under `formulas/` or `salt/`, to change runtime data.

## Secrets in pillar

Secrets come from OpenBao, not plaintext in `git_pillar` — mirrors how OpenTofu already pulls
creds via AppRole. **Never write an actual secret value into a `pillar/*.sls` file.**

- Use Salt's `sdb` (Simple Database) Vault driver: a pillar value is a reference string,
  `sdb://<sdb-profile>/<vault-path>?<key>`, resolved at render time by the master — the pillar
  file itself only ever contains the path, not the value. This keeps secret *references* visible
  and diffable in git, same spirit as `map.jinja` keeping defaults explicit — prefer this over the
  `ext_pillar vault` module, which pulls a whole Vault path into pillar implicitly and is harder to
  reason about from the state/pillar files alone.
- Dedicated AppRole for the master: create a `salt-master` AppRole role in OpenBao (same pattern as
  the existing `opentofu`/`ansible-deploy` roles), with a read-only policy scoped to whatever KV-v2
  path Salt secrets live under (e.g. `homelab/data/salt/*`, or reuse `homelab/` if per-service
  sub-paths are used, e.g. `homelab/data/homepage`).
- Master config (e.g. `/etc/salt/master.d/vault.conf`):
  ```yaml
  vault:
    auth:
      method: approle
      role_id: <role-id>          # not secret, can live in this file
      secret_id: /etc/salt/vault-secret-id   # path to a file, never inline
    server:
      url: https://<openbao-addr>:8200
  sdb:
    osvault:
      driver: vault
  ```
  `role_id`/`secret_id` follow the same rule as everywhere else in this project: never hardcoded
  in a file that goes to git — `secret_id` lives in a file on the master with restricted
  permissions, outside this repo.
- The `vault` sdb driver has **no** path-prefix config option — there is no field that composes a
  base path onto every reference. Each `sdb://` URI must spell out the full KV-v2 path itself,
  data-prefix included: `sdb://osvault/homelab/data/<service>?<key>`, not `sdb://osvault/<service>?<key>`.
- Example usage in a pillar sls: `api_key: sdb://osvault/homelab/data/homepage?api_key` instead of
  a literal value.

Implemented in `formulas/salt-master/vault.sls` (writes `vault.conf`, the sdb profile) and
consumed by `formulas/users` (see its README). `role_id` lives in pillar (`salt-master:lookup`,
git-committed — not secret); `secret_id` is a file placed manually on the master, outside this
repo (see `formulas/salt-master/README.md` "OpenBao AppRole" for the one-time bootstrap step).

Current KV layout: `pillar/GLOBAL.sls` gives every minion's self-named login account a single
*shared* password reference, `sdb://osvault/homelab/data/users/shared?password` (one OpenBao secret for every
account, not one per minion — deliberate, to avoid provisioning ten secrets up front). Switch to
per-minion secrets later by changing that path to `sdb://osvault/homelab/data/users/{{ grains['id'] }}?password`
— pillar-only change, no formula change needed. The secret itself (an already-hashed
`sha512-crypt` value, never plaintext) still has to be written into OpenBao directly (`bao kv put`
or equivalent) — nothing in this repo creates it.

## How the master gets the state tree

The master isn't manually synced — `formulas/salt-master/init.sls` configures it to pull directly
from this repo via `gitfs` (states, both `formulas` and `salt` roots) and `git_pillar` (pillar),
authenticated with a dedicated read-only deploy key generated on the master itself
(`gitfs_update_interval` default 60s). `formulas/salt-master` is the one formula that isn't fully
generic — its `map.jinja` defaults point at this exact repo/remote; override via
`salt-master:lookup` pillar if the repo is ever renamed or forked.

The one-time manual bootstrap procedure (master starts with nothing configured, so `salt-master`
has to be applied once from a local copy to set up gitfs in the first place) is scripted in
`bootstrap.sh` at the repo root (`./bootstrap.sh user@salt-master`) and documented in the root
`README.md` — read it before touching master bootstrap/deploy-key flow. The OpenBao AppRole
`secret_id` this same formula's `vault.sls` needs is a separate manual step the script doesn't
cover (see `formulas/salt-master/README.md` "OpenBao AppRole") — the credential doesn't exist
until you create it in OpenBao yourself.

## Adding a new service

1. Add a formula under `formulas/<name>/` (`map.jinja` + `init.sls` at minimum — follow the
   split-file convention above). If it needs a dedicated user, wire it through the shared `users`
   formula instead of adding local `user.present` states.
2. Add matching pillar under `pillar/<name>.sls` if it needs config/secret data, and reference it
   from `pillar/top.sls`.
3. Add the minion ID to `salt/top.sls`, listing its formula (and any formulas it depends on, e.g.
   `docker`, in order — dependencies first).
4. Push. Either wait for the next gitfs poll or run `salt-run fileserver.update` /
   `salt '<minion>' saltutil.refresh_pillar` to pick it up immediately, then
   `salt '<minion>' state.apply`.

## Useful commands while iterating

- Dry-run before applying: `salt '<minion>' state.apply test=True`
- Apply a single sls without the full top.sls: `salt '<minion>' state.apply <formula>`
- Render a state without applying (check Jinja/pillar resolution): `salt '<minion>' state.show_sls <formula>`
- Inspect what pillar a minion actually sees: `salt '<minion>' pillar.items`
- Force-refresh gitfs/pillar without waiting for the poll interval:
  `salt-run fileserver.update` then `salt '<minion>' saltutil.refresh_pillar`
- Verbose output for debugging a failing state: add `-l debug` to any `salt` command

## What not to do

- Don't add grain-based targeting until a role genuinely applies to more than one minion.
- Don't hardcode values that belong in `map.jinja`/pillar directly into `.sls` files.
- Don't duplicate another formula's logic (user creation, package install patterns) — `require` it.
- Don't add VLAN/network-topology-specific logic to formulas (see Network context above).
