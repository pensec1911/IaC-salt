# orch formula

Orchestrate runs across minions, executed on the master with `salt-run state.orchestrate`.
So far one run: `orch.reboot`, a nightly rolling reboot of the minions with a pending reboot.

## What it manages

- On the master's minion (the highstate, `orch.timer`): `orch-reboot.service` (oneshot,
  `salt-run state.orchestrate orch.reboot`) and `orch-reboot.timer`, daily 03:15
  Europe/Berlin, 40 min timeout, **not** `Persistent` (a night the master was down doesn't turn
  into a reboot run at boot).
- `orch/reboot.sls`: the orchestrate SLS itself. It isn't in `init.sls` because it's never
  applied to a minion.

## orch.reboot

1. Asks every minion (`tgt`) whether `/run/reboot-required` exists. That's the file
   unattended-upgrades leaves after a kernel/libc upgrade, the same one behind
   `os_reboot_required` / `RebootRequired`. Minions that don't answer within `query_timeout`
   are skipped. Nothing pending: a single no-op state, done.
2. Per pending minion, one at a time (`order` first, the rest alphabetically):
   `system.reboot` in 1 min → wait for `salt/minion/<id>/start` (up to `boot_timeout`) →
   a queued highstate. It lines up behind the start reactor's own run (`formulas/salt-master`),
   so it returns once the minion has converged (normally with 0 changes).
3. Any failure (reboot call, boot timeout, highstate error) stops the chain. The remaining
   minions keep their flag and get picked up the next night, and `RebootRequired` keeps firing
   for them.
4. `master_id` (salt-master) last, fire-and-forget: its reboot ends the run itself. After
   the boot, the start reactor applies it like any other minion.

The pending list is fixed when the run starts (Jinja renders once).

A normal reboot plus converge takes a few minutes per minion. If the run hits the 40 min timeout
anyway (a slow boot or a hung highstate), systemd kills `salt-run` mid-chain. The minions not
reached yet, salt-master included, keep their flag for the next night.

Timing: 03:15 + 40 min timeout ends before the Sunday 04:00 restore test (`formulas/backup`)
and stays within arrstack/jellyfin's 03:00–06:00 window
(`pillar/salt-minion-enforce-window.sls`). unattended-upgrades runs ~06:00–07:00 UTC, so a
reboot it requires happens the following night. `RebootRequired` (`for: 26h`) only fires when
that night's run didn't take care of it.

The pillar is compiled for the master's runner id `salt-master_master`, not `salt-master`.
`pillar/top.sls` therefore targets `pillar/orch.sls` at both.

## Usage

```yaml
# salt/top.sls
'salt-master':
  - salt-master
  - orch
```

Schema: `pillar.example.sls`. Data: `pillar/orch.sls`.

## Operating

```sh
salt-run state.orchestrate orch.reboot test=True   # which minions, in what order — touches nothing
sudo systemctl start orch-reboot.service           # run now (mind arrstack/jellyfin by day)
journalctl -u orch-reboot.service                  # last run's output
systemctl list-timers orch-reboot.timer
```

Skip a night: `systemctl stop orch-reboot.timer` (the next hourly self-repair on salt-master
starts it again). Off for good: `orch:lookup:reboot:timer:enabled: False`. Keep a minion out:
`tgt: "* and not jellyfin"` with `tgt_type: compound`.
