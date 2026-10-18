# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

Nothing queued — pick from "Later". Suggested order if you want one: (1) Drift check enforcement
on `homepage`, (2) Beacons → reactor.

## Later

### Beacons → reactor (self-healing)

- `service` beacon on `docker` (and other systemd units) → reactor restarts / re-applies.
- `diskusage` beacon on the NFS mounts (arrstack, jellyfin).
- `inotify` on managed config files → immediate re-apply instead of waiting for the schedule.
- No built-in beacon for individual Docker containers — container health is better covered by
  cadvisor + Alertmanager.
- Reactor plumbing exists (`formulas/salt-master`, `reactor.conf.j2`) — add a mapping there.

### Drift check: real enforcement

- The hourly dry run (`formulas/salt-minion`) only reports. Once `SaltDrift` has stayed quiet
  for a while, selected minions could re-apply on drift instead (schedule `state.apply` without
  `test=True`, or reactor on a drift event). Risky on arrstack (container recreation restarts
  the whole VPN stack) — start with stateless hosts like `homepage`.

### Orchestrate runs across minions

- `state.orchestrate` for ordered multi-minion rollouts (e.g. monitoring first, then the rest;
  or `test=True` everywhere, then apply). Worth it once there's a real cross-minion dependency.

### Event sources via salt-api

- Git push webhook → `fileserver.update` + `git_pillar.update` + highstate (fully automatic
  "push = deploy").
- Alertmanager webhook → reactor (e.g. container down → highstate on that minion).
- Cost: salt-api is new attack surface with its own auth/TLS bootstrap (manual, per the hard
  rules). Only worth it if the drift check and the start reactor prove insufficient.

## Deliberately not

- **Key acceptance via reactor** — keys are currently auto-accepted master-wide
  (`auto_accept: true`, see known-issues.md); if that changes, acceptance goes back to manual
  (security-critical bootstrap, CLAUDE.md hard rules), not to reactor-driven auto-accept.
