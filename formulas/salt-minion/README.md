# salt-minion formula

Minion-side Salt features: **drift detection** and **beacons** (self-healing of stopped
services).

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
`SaltDriftCheckStale`, `SaltDriftCheckMissing`, `SaltDriftRepairFailed`). By default the
check **only reports**. To see *what* drifted: `salt '<minion>' state.apply test=True` on the
master.

## Self-repair (enforce)

With `drift_check.enforce: True` a dry run that shows drift — and no failing states — is
followed by a real `state.apply` and a second dry run. The drift metrics then describe the host
*after* the repair, so `SaltDrift` only fires when the repair didn't converge. Extra metrics:

| Metric | Meaning |
|---|---|
| `salt_drift_enforce` | 1 = this minion self-repairs |
| `salt_drift_repair_last_timestamp_seconds` | when enforce last applied for real |
| `salt_drift_repair_last_success` | 1 = that apply had no failed states (`SaltDriftRepairFailed` on 0) |
| `salt_drift_repair_last_states_changed` | states that apply changed |

On in `pillar/salt-minion-enforce.sls` for homepage, monitoring and salt-master. Not on
arrstack (recreating gluetun restarts the VPN stack) or jellyfin (cuts streams).

Consequence: on those minions **a push deploys itself** within `interval_minutes` + splay, with
no `test=True` first. A failing dry run (render error, failing state) blocks the repair. A
failed repair is retried on the next run. Each of the three runs gets its own
`timeout_seconds`, so one check can take up to 3× that.

Before turning enforce on for another minion, make sure its dry run is clean: a state that
always reports pending in `test=True` (e.g. `cmd.run` without `unless`/`onlyif`) would trigger
a real apply every hour.

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

## Beacons: restart stopped services

`beacons.service` configures Salt's `service` beacon (persisted in
`/etc/salt/minion.d/beacons.conf`, checked every `interval_seconds`). When a listed service has
been down for `delay_seconds`, the minion fires `salt/beacon/<id>/service/<name>` with
`running: False`; the master's reactor (`formulas/salt-master`, "Reactor: restart stopped
services") runs `service.start <name>` on that minion — nothing more, no highstate. It fires on
status changes only, not on every check and not at minion start.

On in `pillar/salt-minion-beacons.sls` for `docker` on the docker hosts (homepage, monitoring,
arrstack, jellyfin). Also on arrstack/jellyfin, which are otherwise report-only: when docker is
down the stack is down already, starting it cuts nothing.

- `docker.service` restarts itself on a crash (`Restart=always`); the beacon covers what that
  doesn't: systemd gave up (start limit, 3 starts/min) or docker was stopped by hand.
  `delay_seconds` (90) > the start-limit interval (60 s), so systemd goes first and the
  reactor's start is no longer refused when it comes.
- **Maintenance**: a docker stopped on purpose comes back after ~90 s. Pause it with
  `salt '<minion>' beacons.disable_beacon service` (not saved, back after a salt-minion
  restart or `beacons.enable_beacon service`).
- On arrstack/jellyfin docker waits for the NFS mount (`nfs-mount` `required_by`). With the NAS
  down the reactor's start fails once and isn't retried (one event per change); start docker
  when the NAS is back, as before.

Check what's configured: `salt '<minion>' beacons.list`. Restarts it triggered:
`salt-run jobs.list_jobs search_function=service.start` on the master.

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

None required. See `pillar.example.sls` (`drift_check.enabled: False` removes it cleanly;
`beacons.service.enabled: False`, the default, removes the beacon).
