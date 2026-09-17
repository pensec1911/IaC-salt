---
name: salt-render-debug
description: Use when a Salt state fails to render, applies stale/wrong data, a new formula or pillar file isn't showing up on a minion, or state.apply behaves unexpectedly. Diagnostic steps for gitfs/git_pillar sync issues and common Jinja/pillar render failures in this repo.
---

# Debugging Salt render/sync issues

Work through these in order — most "weird" Salt behavior in this repo is one of these, not a
logic bug in the formula itself.

## 1. Is the master actually seeing the latest commit?

gitfs/git_pillar poll on an interval (see `formulas/salt-master`), not on every push. Force it:

```
salt-run fileserver.update
salt-run cache.clear_all      # only if fileserver.update doesn't pick up the change — nukes gitfs/pillar cache
```

If `cache.clear_all` was needed, that's a sign the deploy key or gitfs remote config may have
drifted — check `formulas/salt-master`'s `map.jinja` still points at the right repo/branch before
assuming it's just a caching fluke.

## 2. Is the minion pillar actually what you think it is?

Pillar is cached per-minion and doesn't auto-refresh on the minion side even after step 1:

```
salt '<minion>' saltutil.refresh_pillar
salt '<minion>' pillar.items
```

If a key you just added is missing from `pillar.items` output, the problem is in step 1 (master
hasn't picked up the pillar change) or in `pillar/top.sls` (minion ID doesn't match, or the sls
isn't listed for it) — not in the pillar file's content.

## 3. Render the state without applying, to isolate Jinja errors

```
salt '<minion>' state.show_sls <formula>
```

This renders but doesn't execute — fastest way to see a Jinja/YAML error without touching the
system. Common causes in this repo's pattern:

- **`pillar.get` merge behavior**: `merge=True` deep-merges *dicts*. It does NOT merge *lists* —
  a pillar list value fully overwrites map.jinja's default list, it doesn't append. If a formula
  expects a list to accumulate (like `users:accounts` is meant to, once that formula exists), this
  needs `pillar_merge_lists: True` in master config (list merge across separate pillar *sls
  files*), which is a different mechanism from `merge=True` in `pillar.get` (dict merge within one
  resolved value). Don't conflate the two.
- **Missing `with context`**: importing from `map.jinja` without `with context` silently loses
  access to `salt`/`pillar` inside the imported macro/variable — symptoms look like pillar data
  "not existing" even though `pillar.items` shows it.
- **`salt://` vs relative formula paths**: since `formulas/` and `salt/` are merged into one
  gitfs namespace (see CLAUDE.md), a typo'd `include:` path fails silently-ish (state just
  doesn't apply, no obvious error) rather than a clear "file not found."

## 4. Verbose logging for anything still unclear

```
salt '<minion>' state.apply <formula> test=True -l debug
```

Noisy, but shows the actual pillar/grain values Salt resolved at each step — use as a last resort
once 1–3 haven't isolated it.

## 5. sdb://-specific failures

If a state renders fine but a value comes back empty/None where an `sdb://osvault/...` reference
was expected: check the master's vault AppRole auth is valid (`secret_id` files can expire/rotate)
before assuming the pillar syntax is wrong — sdb resolution failures are often silent (empty
value) rather than a hard error.
