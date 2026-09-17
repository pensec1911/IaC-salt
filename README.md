# IaC-salt

SaltStack state tree for the VMs provisioned by [IaC-opentofu](../IaC-opentofu). Tofu creates
the VM, installs `salt-minion` (and `salt-master` on the one VM that needs it) via cloud-init,
and points every minion at the master. This repo owns everything after that: what actually gets
configured on each box.

## Layout

```
formulas/   # the actual state logic — one directory per formula (docker, homepage, ...),
            # each self-contained and pillar-driven: map.jinja, install/config/service.sls,
            # pillar.example.sls, README.md. Nothing in here is environment-specific.
salt/       # environment glue — just top.sls, mapping minion IDs to formulas
pillar/     # pillar tree — the actual per-minion data (e.g. what shows on the homepage
            # dashboard), served via git_pillar, root "pillar"
```

`formulas/` and `salt/` are two different roots of the *same* git remote, merged by gitfs into
one flat fileserver namespace — so `salt://docker/...` and `include: - docker` both resolve
regardless of which directory `docker` physically lives in. This keeps reusable formula code
separate from "which minion runs what," without needing a separate repo per formula. See
`formulas/<name>/README.md` for each formula's own docs.

## Targeting

`salt/top.sls` matches on minion ID, not grains. Every VM in IaC-opentofu maps 1:1 to a single
role (the `name` set in `vms/<name>/main.tf`, which cloud-init also sets as the hostname/minion
ID), so there's nothing for a role/grain layer to abstract over yet. If a role ever needs to
apply to more than one minion, switch that entry to grain matching then — don't add the
indirection speculatively.

## How the master gets the state tree

The master doesn't get a manual `git pull` or a copy of this repo — it's configured
(`formulas/salt-master/init.sls`) to pull directly from this repo via `gitfs` (states, both the
`formulas` and `salt` roots) and `git_pillar` (pillar), authenticated with a dedicated read-only
deploy key generated on the master itself. Once bootstrapped, pushing to this repo is enough;
the master picks up changes on its own (`gitfs_update_interval`, default 60s).

### One-time bootstrap

This is the only manual step — everything after it is state-managed. The master starts with
nothing configured, so the `salt-master` formula has to be applied from a local copy once to
set up gitfs in the first place.

```sh
./bootstrap.sh user@salt-master
```

This stages `formulas/` + `salt/` into one flat directory (reproducing the merged namespace gitfs
provides afterwards), copies it and `pillar/` to the master, applies the `salt-master` formula
locally (`salt-call --local`) to generate the ed25519 deploy key and write the
gitfs/git_pillar/auto_accept config, prints the public key (offers to register it as a read-only
GitHub deploy key via `gh` if it's installed and authenticated, otherwise prompts you to add it by
hand), then restarts `salt-master` and forces a fetch once you confirm the key's in place. It
cleans up its own temp dirs, local and remote, and is safe to re-run if it fails partway through.

From here on, `salt/top.sls` and `formulas/salt-master/init.sls` are themselves fetched over
gitfs — the master manages its own config from the same repo it's pulling.

The script doesn't handle the separate OpenBao AppRole `secret_id` that `formulas/salt-master/
vault.sls` needs (see `formulas/salt-master/README.md` "OpenBao AppRole") — that credential isn't
something this repo can generate, so it stays a manual step.

## Adding a new service

1. Add a formula under `formulas/<name>/` (`map.jinja` + `init.sls` at minimum — see an existing
   formula for the split-file convention).
2. Add matching pillar under `pillar/<name>.sls` if it needs config/secret data, and reference
   it from `pillar/top.sls`.
3. Add the minion ID to `salt/top.sls`, listing its formula (and any formulas it depends on,
   e.g. `docker`, in order).
4. Push. Either wait for the next gitfs poll or run `salt-run fileserver.update` /
   `salt '<minion>' saltutil.refresh_pillar` to pick it up immediately, then
   `salt '<minion>' state.apply`.
