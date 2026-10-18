# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

### 1. Reactor: highstate on minion start

- **Why**: closes the gap between Tofu and Salt — a freshly provisioned or rebooted VM converges
  without someone running `state.apply` by hand.
- **Sketch**: `salt-master` formula manages `/etc/salt/master.d/reactor.conf` mapping
  `salt/minion/*/start` → a reactor SLS (shipped in the formula, path from `map.jinja`) that only
  calls `state.apply` on `data['id']` (or an orchestrate run). Keep the reactor SLS thin.
- **Open**: reboot storms (every reboot = full highstate — acceptable at this size?); interaction
  with the NFS-at-boot ordering on arrstack/jellyfin (mounts must be up before docker states run).
- **Not part of it**: key acceptance stays manual (see "Deliberately not").

### 2. Salt Mine for Prometheus scrape targets

- **Why**: [pillar/prometheus.sls](../../pillar/prometheus.sls) hand-maintains a minion → IP map;
  every new VM means editing it. With mine data a new minion running `node-exporter` gets
  scraped automatically.
- **Sketch**: `mine_functions` (e.g. `network.ip_addrs`) set for all minions (in the existing
  `salt-minion` formula, or pillar `mine_functions`); the prometheus template builds
  targets from `salt['mine.get']('*', 'network.ip_addrs')`, filtered to minions that run
  node-exporter / cadvisor.
- **Open**: how to know which minions run cadvisor (mine a flag, or derive from pillar); the same
  data could replace the hardcoded IPs in [pillar/homepage.sls](../../pillar/homepage.sls).

## Later

### Beacons → reactor (self-healing)

- `service` beacon on `docker` (and other systemd units) → reactor restarts / re-applies.
- `diskusage` beacon on the NFS mounts (arrstack, jellyfin).
- `inotify` on managed config files → immediate re-apply instead of waiting for the schedule.
- No built-in beacon for individual Docker containers — container health is better covered by
  cadvisor + Alertmanager.
- Prerequisite: the reactor item above (reactor plumbing exists).

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
  rules). Only worth it if the drift check and the reactor prove insufficient.

## Deliberately not

- **Auto-accepting minion keys via reactor** — key acceptance is security-critical bootstrap and
  stays manual (CLAUDE.md hard rules).
