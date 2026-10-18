# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

### 1. Backup of service data

- **Why**: everything under `/opt/<app>` that Salt doesn't render is only on the VM — arr
  configs/DBs (~85 MB on arrstack), jellyfin config (66 MB), grafana DB (15 MB). A lost VM means
  re-doing Sonarr/Radarr/Prowlarr setup by hand; the arr major bumps (known-issues.md) need a
  backup first anyway. Images and rendered config are reproducible — not in scope.
- **Sketch**: `backup` formula — restic + systemd timer per minion, repo on a NAS share via
  `nfs-mount`, repo password from OpenBao (sdb). Paths per minion in pillar. Consistent SQLite:
  stop the container briefly, or use the arr apps' own scheduled backup zips. Textfile metrics
  like the drift check → `BackupStale` alert.
- **Open**: which NAS share, retention, include prometheus data (probably not).

## Later

### Beacons → reactor (self-healing)

- `service` beacon on `docker` (and other systemd units) → reactor restarts / re-applies.
- `diskusage` beacon on the NFS mounts (arrstack, jellyfin).
- `inotify` on managed config files → immediate re-apply instead of waiting for the schedule.
- No built-in beacon for individual Docker containers — container health is better covered by
  cadvisor + Alertmanager.
- Reactor plumbing exists (`formulas/salt-master`, `reactor.conf.j2`) — add a mapping there.

### Self-repair on jellyfin / arrstack

- Enforce mode runs on homepage, monitoring, salt-master (`pillar/salt-minion-enforce.sls`).
  jellyfin/arrstack stay report-only: a repair can recreate containers (cuts streams; on
  arrstack restarts the whole VPN stack). Possible: a maintenance window (only repair at night),
  or enforce only once `salt_drift_repair_last_*` has been quiet on the others for a while.

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
