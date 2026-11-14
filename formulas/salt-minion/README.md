# salt-minion formula

Minion-side Salt features: **drift detection**, **beacons** (self-healing of stopped
services) and the **Salt version** (exact apt pin, upgrade via `orch.salt-upgrade`).

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

On in `pillar/salt-minion-enforce.sls` for homepage, monitoring, forgejo and salt-master, at any hour.

### Enforce window (arrstack, jellyfin)

`drift_check.enforce_window` (`start`/`end` "HH:MM" in `timezone`, may wrap midnight) limits the
repair to a time of day; outside it the run only reports. On in
`pillar/salt-minion-enforce-window.sls` for arrstack (recreating gluetun restarts the VPN stack)
and jellyfin (cuts streams): **03:00–06:00 Europe/Berlin**, three hourly runs.

- A push reaches them the following night (the drift check, or `orch.push` if it lands between
  03:00 and 06:00), not within the hour.
- Extra metric `salt_drift_enforce_window_open` (1 = a repair may run now; always 1 without a
  window). `SaltDrift` ignores enforce minions whose window is closed — their drift is expected
  until the night. Drift that survives the window fires during it.
- Repair now instead of at night: plain `salt '<minion>' state.apply`, as before.
- The window must be wider than `interval_minutes` + splay, or a night can pass without a run.

Consequence: on those minions **a push deploys itself**. Usually `orch.push` does it a minute
after the push (`formulas/orch`, with a dry run first). If that doesn't happen, the next check
does it within `interval_minutes` + splay, with no `test=True` first. `orch.push` asks
`salt-drift-check --enforce-allowed` (prints `yes` when enforce is on and the window is open,
and checks nothing else) to decide which minions it may touch. A failing dry run (render error, failing state) blocks the repair. A
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

Currently on nowhere. It watched `docker` on the container hosts until the Podman migration
(2026-11); Podman has no daemon, and each Quadlet unit restarts itself (`Restart=always`). To
watch a service again: `salt-minion:lookup:beacons:service` in a pillar file targeted at the
minion, plus the service in `salt-master:lookup:beacon_restart_services`. `delay_seconds` (90)
must stay above the unit's start-limit interval, so systemd's own restart goes first.

Check what's configured: `salt '<minion>' beacons.list`. Restarts it triggered:
`salt-run jobs.list_jobs search_function=service.start` on the master.

## Salt version

Salt comes from Broadcom's repo, which unattended-upgrades leaves alone. Tofu's cloud-init
pins it only to the line (`/etc/apt/preferences.d/salt-pin-1001`, `3008.*`). With
`version.target` set (`pillar/salt-minion-version.sls`, all hosts):

- `version.sls` (highstate): takes over that pin file and pins `salt-*` to **exactly** the
  effective version, so `apt upgrade` can't move Salt. An installed package **newer** than the
  pin fails the state, which shows up as drift. It upgrades nothing.
- **Master first, built in:** every host except `master_id` is capped at `master_running`,
  which is the version of the salt-master rendering the pillar (`test.version` runs in the
  master). Until the master runs the target, the minions' pin stays at the master's version,
  whatever order a push, drift check or start reactor applies things in.
- `upgrade.sls` (not in `init.sls`): only `orch.salt-upgrade` (`formulas/orch`) applies it. It
  installs `salt-*=<effective>` for every Salt package installed on the host, via
  `/usr/local/sbin/salt-upgrade` in a transient unit `salt-upgrade`, 15 s later. It has to run
  outside the minion: the package's postinst restarts salt-minion, and `KillMode=mixed` would kill
  an apt started from within the minion halfway through dpkg configure. The script first waits until
  no Salt job runs on the minion (`/var/cache/salt/minion/proc` empty, max 15 min, then it
  gives up). If the upgrade changes the bundled Python, it reinstalls the salt-pip extras
  (`extras-<py>`: pygit2, saltext.vault — without pygit2 the master has no gitfs) and restarts
  the active salt services. Log: `journalctl -u salt-upgrade`.

Bump: Renovate proposes it (`renovate.json`, deb datasource, 3008 line only). Then merge and
push, and run `orch.salt-upgrade` on the master twice (README of `formulas/orch`).

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
