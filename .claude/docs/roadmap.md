# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

_Nothing agreed yet — pick from "Later"._

## Later

No order agreed; pick as needed.

### Alertmanager receiver (notification channel)

- **Why**: `pillar/alertmanager.sls` is empty, so the "null" receiver applies. Alerts from
  `pillar/prometheus.sls` (DiskAlmostFull, RebootRequired, CertificateExpiringSoon) and
  Wazuh (level >= 10, critical CVEs) are only visible if someone opens the UI or Grafana.
- **Sketch**: pick one channel (ntfy, Telegram or mail), set `alertmanager:config` in
  `pillar/alertmanager.sls` with the URL/token via `sdb.get` from OpenBao; route by severity,
  group Wazuh alerts so a CVE burst is one message.
- **Open**: which channel (self-hosted ntfy needs its own formula + homepage entry); whether
  alerts should still arrive when the monitoring VM itself is down (dead-man's switch).

### Offsite copy of the restic repos

- **Why**: `formulas/backup` writes every minion's repo to `/mnt/backups/<minion>` on the NAS
  only. The weekly restore test proves the repos are good, but NAS loss (or the house) takes
  the data and all its backups together; that includes Forgejo, now the master's source of truth.
- **Sketch**: a timer on one minion (e.g. forgejo or monitoring, both mount the NAS) runs
  `restic copy` from each NAS repo to an S3/B2/Hetzner-style target, with credentials and the
  repo password via `sdb.get` from OpenBao. Pillar-driven in `formulas/backup`; weekly, after
  the restore test.
- **Open**: which provider; whether copying only forgejo, wazuh keys and the *arr/jellyfin
  configs (not media) is enough; how the offsite repo password is kept outside OpenBao itself
  (losing OpenBao loses the key to the copy). OpenBao isn't backed up at all yet
  (known-issues.md "Backup gaps") — fix that first, then its snapshot goes offsite too.

### Salt version upgrades via orch.rollout

- **Why**: salt-minion/salt-master come from the Salt repo, which unattended-upgrades excludes
  on purpose (`formulas/unattended-upgrades`), and the version isn't pinned anywhere. So Salt
  is either never upgraded or moves by accident with a manual `apt upgrade`, and minions can
  drift apart in version. The master must never be older than its minions.
- **Sketch**: pin the version in pillar (`salt-minion:lookup:version`, same for salt-master)
  with `pkg.installed: version=` plus an apt preference so a stray `apt upgrade` can't move it.
  A bump runs through `orch.rollout` in the right order: master first, then the minions
  one at a time with a `test.ping` / drift check after each restart. Renovate (already
  running for images) can propose the bump via a regex manager on the pillar pin. The
  onedir extras (pygit2 etc. via `salt-pip`, formulas/salt-master) must survive an upgrade
  — verify in the first rollout.
- **Open**: how a minion restarting its own salt-minion mid-state reports back (Salt's
  documented pattern is a delayed restart via `cmd.run` with `bg: True`); whether arrstack/
  jellyfin wait for their nightly window; how the restart interacts with the start reactor
  (known-issues.md: master restart → highstate everywhere).

## Deliberately not

- **Key acceptance via reactor** — keys are currently auto-accepted master-wide
  (`auto_accept: true`, see known-issues.md); if that changes, acceptance goes back to manual
  (security-critical bootstrap, CLAUDE.md hard rules), not to reactor-driven auto-accept.
- **diskusage beacon on the NFS mounts** — `DiskAlmostFull` (pillar/prometheus.sls) already
  covers them (`nfs4` isn't excluded), and there's nothing to heal automatically.
- **inotify beacon → re-apply on config change** — needs pyinotify in the onedir bundle, fires
  on Salt's own writes too (double highstate), and on arrstack/jellyfin it would be self-repair
  through the back door. The hourly enforce run covers the other minions.
