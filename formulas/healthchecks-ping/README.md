# healthchecks-ping formula

Client side of [formulas/healthchecks](../healthchecks/README.md): installs `/usr/local/sbin/hc-ping`,
which other formulas' jobs call to ping their check by slug. Applied on every minion (before
`salt-minion` and `backup` in `salt/top.sls`).

## What it manages

With a ping key in pillar:

- `curl`, `/etc/healthchecks-ping/env` (root 0600, diff hidden: `HC_PING_URL=<base_url>/ping/<key>`).
- `/usr/local/sbin/hc-ping <slug> <status>` — status `0`, `fail`, an exit code, or `systemd`
  (reads `$SERVICE_RESULT`, for `ExecStopPost=`). Sends
  `<base_url>/ping/<key>/<slug>[/fail|/<code>]?create=1` — the check is created on its first ping.

Without one (empty or unresolved): removes both — nothing pings, and the consumers render no
ping line at all (they read `enabled` from this formula's `map.jinja`).

A ping never breaks or delays its job: `hc-ping` hands the request to a transient systemd unit
(`systemd-run --no-block`) and exits 0 at once; there curl retries every 15 s for up to 5 min
(covers Healthchecks' own ~1 min stop during jellyfin's nightly backup). The key stays in the
root-only env file, never on a command line.

## Who pings

| Slug | From | When |
|---|---|---|
| `drift-check-<minion>` | `formulas/salt-minion` drift-check script | after each hourly check: `0` if the dry run completed, else `fail` |
| `backup-<minion>` | `formulas/backup` `restic-backup.service` `ExecStopPost` | after each nightly run, from the unit result |
| `restore-test-<minion>` | `formulas/backup` `restic-restore-test.service` `ExecStopPost` | after each weekly test |
| `alertmanager-watchdog` | Alertmanager webhook (`pillar/alertmanager.sls`, not this formula) | every ~2 min |

Test on a minion: `hc-ping drift-check-$(hostname) 0; journalctl -n 5 | grep -i ping`.

## Pillar

See `pillar.example.sls`. Real values in `pillar/healthchecks-ping.sls`.
