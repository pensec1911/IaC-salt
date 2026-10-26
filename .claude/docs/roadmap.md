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

### Forgejo + Renovate (long term)

- **Why**: master pulls from GitHub today; a local Forgejo keeps repo + deploy in the LAN and
  gives a push webhook in the LAN. salt-api is already running (`formulas/salt-master`), so this
would be `/hook/git` plus a reactor that checks the HMAC (`hashutil.github_signature`) and runs
`fileserver.update`; deploy on push already follows from the gitfs event. Renovate would open PRs for
  the pinned image versions instead of bumping them by hand.
- **Sketch**: own VM via Tofu, `forgejo` formula; gitfs/git_pillar remote + deploy key switch
  over; GitHub as a mirror. Renovate as a Forgejo Actions job or a container.
- **Open**: runner for Actions; backup of Forgejo itself becomes critical (it holds the deploy
  source) — an entry in `pillar/backup.sls`.

## Deliberately not

- **Key acceptance via reactor** — keys are currently auto-accepted master-wide
  (`auto_accept: true`, see known-issues.md); if that changes, acceptance goes back to manual
  (security-critical bootstrap, CLAUDE.md hard rules), not to reactor-driven auto-accept.
- **diskusage beacon on the NFS mounts** — `DiskAlmostFull` (pillar/prometheus.sls) already
  covers them (`nfs4` isn't excluded), and there's nothing to heal automatically.
- **inotify beacon → re-apply on config change** — needs pyinotify in the onedir bundle, fires
  on Salt's own writes too (double highstate), and on arrstack/jellyfin it would be self-repair
  through the back door. The hourly enforce run covers the other minions.
