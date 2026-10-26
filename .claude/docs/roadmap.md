# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

_Nothing agreed yet — pick from "Later"._

## Later

### Forgejo + Renovate (long term)

- **Why**: master pulls from GitHub today; a local Forgejo keeps repo + deploy in the LAN and
  gives an easy push webhook (see "Event sources via salt-api"). Renovate would open PRs for
  the pinned image versions instead of bumping them by hand.
- **Sketch**: own VM via Tofu, `forgejo` formula; gitfs/git_pillar remote + deploy key switch
  over; GitHub as a mirror. Renovate as a Forgejo Actions job or a container.
- **Open**: runner for Actions; backup of Forgejo itself becomes critical (it holds the deploy
  source) — an entry in `pillar/backup.sls`.

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
- **diskusage beacon on the NFS mounts** — `DiskAlmostFull` (pillar/prometheus.sls) already
  covers them (`nfs4` isn't excluded), and there's nothing to heal automatically.
- **inotify beacon → re-apply on config change** — needs pyinotify in the onedir bundle, fires
  on Salt's own writes too (double highstate), and on arrstack/jellyfin it would be self-repair
  through the back door. The hourly enforce run covers the other minions.
