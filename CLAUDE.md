# CLAUDE.md

SaltStack state tree for the homelab VMs that `IaC-opentofu` (sibling repo) provisions. Tofu
creates each VM and installs/points `salt-minion` at the master; this repo owns everything after
that. Pure Salt YAML + Jinja — no build/test/lint tooling. The master pulls this repo itself via
gitfs/git_pillar, so **a push is a deploy** (after `state.apply`).

```
formulas/   reusable, pillar-driven formula per service — nothing environment-specific
salt/       top.sls only: minion ID -> formulas
pillar/     per-minion data (git_pillar)
.claude/    docs/, skills, agents, commands for working on this repo
.githooks/  pre-commit secret scanner (enabled via core.hooksPath, set by a SessionStart hook)
```

## Docs — read the relevant one before working in that area

| File | Covers |
|---|---|
| [.claude/docs/architecture.md](.claude/docs/architecture.md) | gitfs merge of `formulas/`+`salt/`, master bootstrap, targeting, formula anatomy |
| [.claude/docs/patterns.md](.claude/docs/patterns.md) | users formula, NFS mounts, VPN sidecar + port forwarding, manual bootstrap steps, blockreplace, image pinning, network topology |
| [.claude/docs/secrets.md](.claude/docs/secrets.md) | OpenBao/sdb mechanics, KV layout, `bao` CLI |
| [.claude/docs/inventory.md](.claude/docs/inventory.md) | minions, IPs, ports, NAS, VPN provider, how to reach hosts |
| [.claude/docs/operations.md](.claude/docs/operations.md) | deploy/debug commands, gotchas, runtime facts |
| [.claude/docs/known-issues.md](.claude/docs/known-issues.md) | open bugs and todos |
| [.claude/docs/roadmap.md](.claude/docs/roadmap.md) | planned extensions (event-driven Salt etc.) — delete an item when it ships |
| `formulas/<name>/README.md` | what that formula manages, its pillar, its manual steps |

## Hard rules

- **Secrets**: never a literal value anywhere in the repo — including `.claude/` and docs. The
  pre-commit hook (`.githooks/`, `/secret-scan`) blocks the obvious ones; never `--no-verify`. In pillar, always
  `{{ salt['sdb.get']('sdb://osvault/homelab/data/<path>?<key>') | yaml_encode }}` — never a bare
  `sdb://` string (silently not resolved). Details: [secrets.md](.claude/docs/secrets.md).
- **Formula convention**: defaults only in `map.jinja` (`pillar.get('<f>:lookup', default=…,
  merge=True)`); `init.sls` is just an include list; plus `pillar.example.sls` and `README.md`.
  No hardcoded values in `.sls` files. Reference: `formulas/docker`, `formulas/homepage`.
- **Don't duplicate, require**: dependencies via `require: - sls: <dep>` and listed first in
  `salt/top.sls`. Service users come from the shared `users` formula
  (`require: - user: user-<name>`), mounts from `nfs-mount` (`require: - mount: nfs-mount-<name>`)
  — never local `user.present`/`mount.mounted`.
- **Targeting by minion ID** in both `salt/top.sls` and `pillar/top.sls`; no grain matching until
  a role spans several minions.
- **Runtime data lives in `pillar/<name>.sls`**, not in `formulas/` or `salt/`.
- **No VLAN/subnet/firewall-aware logic** in formulas or pillar — network design lives in the
  Tofu/OPNsense repos.
- **Security-critical bootstrap stays manual and documented** rather than guessed (TLS certs,
  auth-plugin init, AppRole `secret_id`).
- **Patch shipped package config** with `file.blockreplace`, don't replace it wholesale.

## Workflow

1. New service: `/new-service <name>` (scaffolds per convention). Secrets: `/salt-secrets`.
2. After editing `.sls`/`map.jinja`/pillar: the `salt-reviewer` agent can check conventions.
3. Commit + push, then on the master (`ssh salt-master`): `salt-run fileserver.update`,
   `salt-run git_pillar.update`, `salt '<minion>' saltutil.refresh_pillar`,
   `salt '<minion>' state.apply test=True`, then without `test=True`. Full `state.apply`, not
   `state.apply <formula>`. More: [operations.md](.claude/docs/operations.md); render/sync
   problems: `/salt-render-debug`.

4. After a roadmap item ships or a new formula/minion lands: run the `roadmap-curator` agent in
   the background to prune `roadmap.md` and add fitting ideas.

Keep this file short: rules and pointers only. New detail goes into the matching
`.claude/docs/*.md` or formula README; new open problems into `known-issues.md`.
