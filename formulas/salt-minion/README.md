# salt-minion formula

Minion-side Salt features. Today: **drift detection**.

## Drift check

A Salt schedule job (`drift-check`, persisted in `/etc/salt/minion.d/_schedule.conf`) runs
`/usr/local/sbin/salt-drift-check` every hour (+ up to 5 min splay). The script runs
`salt-call state.apply test=True` and writes the result to
`/var/lib/prometheus/node-exporter/salt_drift.prom`, which node-exporter's textfile
collector exposes:

| Metric | Meaning |
|---|---|
| `salt_drift_check_success` | 1 = dry run completed and rendered; 0 = render error, timeout, master unreachable |
| `salt_drift_states_pending` | states the dry run would change — the drift |
| `salt_drift_states_failed` | states with `result: False` in the dry run |
| `salt_drift_states_total` | states in the highstate |
| `salt_drift_duration_seconds` | how long the dry run took |
| `salt_drift_last_run_timestamp_seconds` | when it last finished |

Alerts on these live in `pillar/prometheus.sls` (`SaltDrift`, `SaltDriftCheckFailing`,
`SaltDriftCheckStale`, `SaltDriftCheckMissing`). The check **only reports** — it never applies. To see *what* drifted:
`salt '<minion>' state.apply test=True` on the master.

Drift means the minion differs from git: a hand edit on the VM, a container changed outside
Salt — or a commit that was pushed but not yet applied. After a push, the alert clears once
`state.apply` has run and the next check has passed.

The schedule also fires right when salt-minion starts. That usually collides with the
master's start reactor (`formulas/salt-master`), which runs the real highstate at the same
moment — the retry below makes the check land after it, so the first metric after a reboot
reflects the converged state.

While another `state.apply` holds the lock ("function is running as PID …"), the script retries
every 30 s until `timeout_seconds`. Not `queue=True`: a queued run only returns "Job queued
for execution" and its result never reaches the script.

## Usage

Every minion, after `node-exporter` (it writes into that package's textfile directory, and
requires `sls: node-exporter`):

```yaml
# salt/top.sls
'some-minion':
  - users
  - wazuh-agent
  - node-exporter
  - salt-minion
```

Run it once by hand: `salt '<minion>' schedule.run_job drift-check`, then
`salt '<minion>' cmd.run 'cat /var/lib/prometheus/node-exporter/salt_drift.prom'`.

## Pillar

None required. See `pillar.example.sls` (`drift_check.enabled: False` removes it cleanly).
