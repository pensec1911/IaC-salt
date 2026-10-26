---
description: Roll pushed changes out to one or more minions — sync, dry run, summary, then apply only after OK
argument-hint: <minion> [minion …] | all
---

Deploy to: $ARGUMENTS

Steps (operations.md "Deploy a change"). All `salt` commands via `ssh salt-master "sudo …"`.

1. **Pushed?** `git status` and `git log origin/main..HEAD` — unpushed commits: push first
   (the pre-push render check must pass; never bypass it). The master only sees what's on Forgejo (`origin`).
2. **Targets.** `all` = every minion whose formulas or pillar the commits since the last deploy
   touch: map changed paths under `formulas/<f>`, `pillar/<f>.sls` to minions via `salt/top.sls`
   and `pillar/top.sls` (`GLOBAL`, `'*'`-pillar → every minion). Name the list before going on.
   homepage, monitoring and salt-master (and arrstack/jellyfin from 03:00 to 06:00) already got
   the push from `orch.push` a minute after it landed. Check
   `salt-run jobs.list_jobs search_function=runner.state.orchestrate` and drop them if it
   succeeded.
3. **Sync.** `salt-run fileserver.update`, `salt-run git_pillar.update`, then
   `salt '<targets>' saltutil.refresh_pillar` (list targeting: `-L a,b`).
4. **Dry run.** `salt -L <targets> state.apply test=True --state-output=changes --state-verbose=False`.
   Full highstate, never `state.apply <formula>`.
5. **Summarize per minion**, short: which states change and what (file diff gist, container
   recreated → which ones restart; gluetun recreated restarts all of arrstack). Leave out known
   noise: `'docker_container.running' is not available` on a fresh minion. Failures → stop,
   use `/salt-render-debug`.
6. **Stop and ask for OK** — applying is outward-facing, and the user wants a per-task go
   (memory "Push yes, deploy ask"). Mention restarts/downtime and, on arrstack/jellyfin outside
   03:00–06:00, that the nightly window would apply it anyway.
7. After OK: `salt -L <targets> state.apply --state-output=changes --state-verbose=False`.
   Report failed states verbatim.
8. **Check.** Run a second `test=True` (should show no pending changes), then
   `python3 .claude/skills/homelab-status/status.py <minion>` per target. Drift metrics refresh
   hourly, so a stale `Np` right after the apply is expected — the second dry run is the truth.
