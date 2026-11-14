---
name: roadmap-autopilot
description: Use when asked to work through .claude/docs/roadmap.md autonomously ("arbeite die Roadmap ab", autopilot). Orchestrates one worker agent per roadmap item, each building a stacked branch + Forgejo PR up to a green render check, without asking between items. Never merges, never applies, never touches Tofu; collects secrets and manual steps for the user at the end. Respects the hardware budget in .claude/docs/capacity.md.
---

# Roadmap autopilot (semi-autonomous)

The user reviews and merges at the end, in one go, after putting the collected secrets into
OpenBao. Until then nothing reaches a VM: work happens only on `autopilot/*` branches, and
branch pushes don't deploy (`orch.push` and the pre-push render hook only act on `main`).

## Allowed without asking

- Create `autopilot/<nn>-<slug>` branches, commit, push them, open PRs against `main` in Forgejo
  (token: memory `reference-forgejo-api`, never printed).
- Run the render check on the master for a branch (below), read Prometheus/Alertmanager.

## Never

- Merge a PR, push to `main` (docs-only autopilot bookkeeping excepted), `state.apply` (not even
  `test=True` against a branch), `tofu apply`, touch `IaC-opentofu` or OpenBao.
- `--no-verify`, `SKIP_RENDER_CHECK`, literal secrets anywhere.
- Start the next item while the current one's render check is red.
- Pick items with security-critical manual bootstrap (PKI root, SSH CA, Velociraptor CA,
  salt-api TLS) or that need a design decision the roadmap lists as open with no default
  (reverse proxy CA choice, SSO product, offsite provider), or a new VM. Those go to the report.

## Orchestrator (main session)

1. `python3 .claude/skills/roadmap-autopilot/capacity.py` and read `.claude/docs/capacity.md`.
2. Pick the batch from roadmap "Later" (or "Next up" if set): automatable items, ordered so
   dependencies come first (ntfy before anything that notifies). Assign each a minion that
   passes the capacity rules **including the previous items' planned rows**. Tell the user the
   batch, placement and order in one short message, then go — don't wait for an OK unless a
   placement needs a Tofu change.
3. Items run **sequentially, stacked**: item n branches from item n-1's branch (item 1 from
   `origin/main`), so shared files (`salt/top.sls`, `pillar/top.sls`, `pillar/homepage.sls`,
   `pillar/backup.sls`, `capacity.md`, `roadmap.md`) never conflict. One worker agent per item
   (`general-purpose`, `isolation: "worktree"`, background), prompt from the template below.
4. When a worker reports: check its PR's render status yourself, check its capacity row, then
   start the next one. A worker that reports blocked → note it, skip it, base the next item on
   the last good branch.
5. Stop after the batch, on two blocked items in a row, or if a capacity check fails.
6. Final report to the user (German, short): PRs in merge order with links, the **secrets
   checklist** (per PR: OpenBao path + key + the ready-to-paste `bao kv put/patch` command,
   see Worker rule 3), manual steps, capacity
   before/after, skipped items and why. Merge order matters: merge with a merge commit,
   oldest first; secrets of a PR into OpenBao **before** merging it (a merge deploys within a
   minute via `orch.push`).

## Worker prompt template

> You are a worker of the roadmap autopilot in the IaC-salt repo (your worktree). Read
> `CLAUDE.md`, `.claude/skills/roadmap-autopilot/SKILL.md` ("Worker rules"),
> `.claude/docs/capacity.md`, and the roadmap entry "<title>" in `.claude/docs/roadmap.md`.
> Item <nn>: <title>. Target minion: <minion> (budget: ≤ <X> MB RAM, ≤ <Y> GB disk).
> Base branch: <base>. Your branch: `autopilot/<nn>-<slug>`. Decisions already made: <…>.
> Report back: branch, PR URL, render status, secrets checklist, manual steps, capacity row,
> open decisions you made a default for. Don't ask questions — decide, document, report.

## Worker rules

1. `git fetch origin && git switch -c autopilot/<nn>-<slug> origin/<base>` (in your worktree).
2. Build per `.claude/commands/new-service.md` and CLAUDE.md hard rules (map.jinja defaults,
   podman macro, users/nfs-mount via require, homepage item, backup entry, inventory.md row,
   formula README with manual steps). Pin images to the current upstream tag — look it up.
   Check the image size against the disk budget.
3. **Secrets**: only `sdb.get` references, path proposed under `homelab/<service>/…`. A missing
   secret must fail the state loudly, never start a service with an empty credential — guard
   like `formulas/netbox/config.sls` (`test.fail_without_changes`). List each secret in the PR
   **with the ready-to-paste command** for the OpenBao host (the user runs `bao` there):
   - generated value: `bao kv put -mount=homelab <path> <key>="$(openssl rand -base64 32)"`
     (or `-hex 32` / the format the service needs)
   - value that comes from elsewhere (API token from a UI): `bao kv put -mount=homelab <path> <key>=-`
     then paste + Ctrl-D (stdin, so it stays out of shell history)
   - path already exists (other keys under it): `bao kv patch` instead of `put` — `put`
     replaces every key at the path. Check the KV layout in `.claude/docs/secrets.md`.
   - several keys at one path: one command with all of them.
   - check: `bao kv get -mount=homelab <path>`.
   Also add new paths to the KV layout table in `.claude/docs/secrets.md`.
4. Resolve the roadmap entry's open points with the simplest safe default; write each choice in
   the PR description under "Decisions" so the user can veto it.
5. Append your row to "Planned additions" in `.claude/docs/capacity.md`; delete the item's
   entry from `.claude/docs/roadmap.md`.
6. Run the `salt-reviewer` agent on your diff; fix what it reports.
7. Render check on the master (same as the pre-push hook, works for any branch):
   `git archive HEAD formulas salt pillar | ssh -o BatchMode=yes salt-master 'd=$(mktemp -d) && tar -x -m -C "$d" && python3 "$d/formulas/salt-master/files/render-check.py" "$d"; rc=$?; rm -rf "$d"; exit $rc'`
   Must pass before pushing. Unresolved `sdb.get` renders as empty — that's expected until the
   user fills OpenBao, the guard from rule 3 handles it at apply time.
8. Commit (conventional message, `feat(<formula>): …`), `git push -u origin <branch>`, open a PR
   against `main` via the Forgejo API (`POST /api/v1/repos/homelab/IaC-salt/pulls`), title
   `[autopilot <nn>] <title>`, body: summary, "Depends on: #<prev PR> (merge first)", Decisions,
   Secrets checklist, Manual steps, Capacity. Wait for the PR's `render-check` status
   (`GET /api/v1/repos/homelab/IaC-salt/commits/<sha>/status`); red → fix, push, repeat.
9. Blocked (needs a decision, budget doesn't fit, render can't be fixed in 3 tries): push what
   you have as a draft-titled PR (`WIP:`) only if it's useful, and report why.
