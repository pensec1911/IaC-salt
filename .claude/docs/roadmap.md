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

### blackbox_exporter (HTTP probes)

- **Why**: cAdvisor only shows a container is running, not that the app answers. A hung
  Sonarr or a Jellyfin stuck at startup is invisible today.
- **Sketch**: `blackbox-exporter` formula on monitoring (docker, cadvisor pattern). Probe
  targets from the Salt Mine like node_exporter/cadvisor — each service formula publishes its
  URL as a mine entry, Prometheus builds `http_2xx` jobs from it. `ProbeFailed` alert in
  alertmanager. The mine reactor (formulas/salt-master) already re-applies mine consumers.
- **Open**: arrstack apps sit behind gluetun — probe the ports gluetun exposes; auth-protected
  endpoints (accept 401 as "up"?).

### Loki + Alloy (container logs)

- **Why**: Wazuh covers security logs, but app logs (failed Sonarr import, Jellyfin errors)
  are only reachable via `docker logs` on the VM. Grafana is already there.
- **Sketch**: `loki` formula on monitoring, `alloy` formula on every docker host (scrapes the
  docker socket, ships to Loki). Loki URL for Alloy from the mine, not hardcoded. Grafana
  datasource via the grafana formula's provisioning.
- **Open**: retention / disk on monitoring; whether Alloy also replaces cadvisor/node_exporter
  later (probably not — keep it to logs).

### Forgejo + Renovate (long term)

- **Why**: master pulls from GitHub today; a local Forgejo keeps repo + deploy in the LAN and
  gives an easy push webhook (see "Event sources via salt-api"). Renovate would open PRs for
  the pinned image versions instead of bumping them by hand.
- **Sketch**: own VM via Tofu, `forgejo` formula; gitfs/git_pillar remote + deploy key switch
  over; GitHub as a mirror. Renovate as a Forgejo Actions job or a container.
- **Open**: runner for Actions; backup of Forgejo itself becomes critical (it holds the deploy
  source) — after the backup item.

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
- **diskusage beacon on the NFS mounts** — `DiskAlmostFull` (pillar/prometheus.sls) already
  covers them (`nfs4` isn't excluded), and there's nothing to heal automatically.
- **inotify beacon → re-apply on config change** — needs pyinotify in the onedir bundle, fires
  on Salt's own writes too (double highstate), and on arrstack/jellyfin it would be self-repair
  through the back door. The hourly enforce run covers the other minions.
