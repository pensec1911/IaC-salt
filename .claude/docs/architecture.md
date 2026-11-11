# Architecture

## Where this repo sits

`IaC-opentofu` (sibling repo) creates each VM on Proxmox, installs `salt-minion` (and
`salt-master` on the one VM that needs it) via cloud-init, sets the hostname = minion ID = the Tofu
VM `name`, and points every minion at the master. This repo owns everything after that.
Networking/VLAN design lives in `IaC-opentofu` / the OPNsense repo, not here — see
[patterns.md](patterns.md#network-topology).

## Three roots, one namespace

```
formulas/   state logic, one self-contained, pillar-driven directory per formula
salt/       environment glue — only top.sls (minion ID -> formulas)
pillar/     per-minion data, served via git_pillar (root "pillar")
```

`formulas/` and `salt/` are two roots of the **same** git remote, merged by gitfs into one flat
fileserver namespace. `salt://docker/...` and `include: - docker` resolve regardless of which
directory `docker` physically lives in. This keeps reusable formula code apart from "which
minion runs what" without a repo per formula.

## How the master gets the state tree

The master pulls straight from this repo — no manual sync:

- **gitfs** serves states (both `formulas` and `salt` roots, branch `main` as `base`).
- **git_pillar** serves `pillar/`.
- Source: Forgejo `homelab/IaC-salt` (`salt-master:lookup:gitfs_remote` in pillar), GitHub only
  mirrors it.
- Auth: a read-only deploy key generated on the master itself.
- Poll interval: `gitfs_update_interval`, default 60 s. A push to main also fetches at once via
  Forgejo's webhook to salt-api `/hook/git` (formulas/salt-master README "salt-api").

All of that is configured by `formulas/salt-master` — the one formula that isn't fully generic
(its `map.jinja` defaults point at `pensec1911/IaC-salt`; override via `salt-master:lookup` if the
repo is renamed/forked). The master therefore manages its own config from the same repo it pulls.

**Bootstrap** (one-time, master starts with nothing): `./bootstrap.sh user@salt-master` — stages
`formulas/`+`salt/` into one flat dir (mimicking the gitfs merge), applies `salt-master` locally
with `salt-call --local`, prints the deploy key, then restarts the master. Full walkthrough in the
root [README.md](../../README.md). The OpenBao AppRole `secret_id` is a separate manual step —
see [secrets.md](secrets.md#bootstrap-the-approle).

## Targeting

- `salt/top.sls` matches **minion ID**, not grains. Every VM is exactly one role. Don't add grain
  indirection until a role really spans more than one minion.
- `pillar/top.sls` mirrors it: `'*': [GLOBAL, wazuh-agent]` plus one entry per minion that needs
  data, using the same minion ID.
- Runtime data (dashboard entries, mounts, VPN settings…) lives in `pillar/<name>.sls` — edit
  that, not anything under `formulas/` or `salt/`.

## Formula anatomy

Reference: `formulas/docker`, `formulas/homepage`.

| File | Role |
|---|---|
| `map.jinja` | The **only** place defaults live: `defaults` dict overlaid with `salt['pillar.get']('<formula>:lookup', default=defaults, merge=True)`. Other files import it `with context`. |
| `init.sls` | Only an `include:` list wiring the other files. |
| `install.sls` / `config.sls` / `service.sls` / `container.sls` | The actual states, split by concern. |
| `pillar.example.sls` | Documents the pillar schema (defaults + what's required in practice). Not consumed. |
| `README.md` | What it manages, `salt/top.sls` usage, pillar, anything manual. |

A formula depending on another declares `require: - sls: <dep>` and the dependency is listed
**before** it for that minion in `salt/top.sls`. Never duplicate another formula's logic.

Note: requisites like `user: user-media` or `mount: nfs-mount-media` only resolve when the
providing formula is in the same run — so `state.apply <formula>` alone fails for formulas that
depend on `users`/`nfs-mount`. Use a full `state.apply` on the minion (see
[operations.md](operations.md)).
