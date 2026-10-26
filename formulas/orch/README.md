# orch formula

Orchestrate runs across minions, executed on the master with `salt-run state.orchestrate`.
Two runs:

- `orch.reboot`: a nightly rolling reboot of the minions with a pending reboot.
- `orch.rollout`: an ordered highstate across minions, started by hand. It does a dry run on all of them first.
- `orch.push`: `orch.rollout` limited to the minions that may self-repair right now, started
  by the master's reactor when a push arrives (`formulas/salt-master` "deploy on push").

## What it manages

- On the master's minion (the highstate, `orch.timer`): `orch-reboot.service` (oneshot,
  `salt-run state.orchestrate orch.reboot`) and `orch-reboot.timer`, daily 03:15
  Europe/Berlin, 40 min timeout, **not** `Persistent` (a night the master was down doesn't turn
  into a reboot run at boot).
- `orch/reboot.sls`, `orch/rollout.sls`, `orch/push.sls`: the orchestrate SLS files (the
  rollout itself is a macro in `orch/rollout.jinja`, shared by the last two). They aren't in `init.sls`
  because they're never applied to a minion.

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

## orch.rollout

For a change that spans several minions. It takes the place of the per-minion
`state.apply test=True` → `state.apply` sequence from CLAUDE.md, run after
`fileserver.update` / `git_pillar.update`. Not scheduled.

1. Every minion in `tgt` that answers `test.ping` takes part. Minions that are down are left
   out, not waited for.
2. `dry-run`: a single `test=True` highstate on all of them. A render error or a state that
   would fail on any minion stops the run before anything changes.
3. A real highstate on each minion, one at a time (`order` first, the rest alphabetically,
   queued behind a running drift check). The first failure stops the chain, so later minions
   stay untouched.
4. `master_id` last. Its highstate may restart salt-master (`watch_in` on its config), which can
   cut the run's own output. Check the result afterwards with `salt-run jobs.list_jobs`.

arrstack and jellyfin are included by default. By day, a highstate there can recreate
containers (VPN stack, Jellyfin streams), so leave them out unless the change is meant for them:

```sh
salt-run state.orchestrate orch.rollout test=True   # dry run on all, applies shown as test
salt-run state.orchestrate orch.rollout
salt-run state.orchestrate orch.rollout \
  pillar='{"orch": {"lookup": {"rollout": {"tgt": "* and not L@arrstack,jellyfin", "tgt_type": "compound"}}}}'
salt-run state.orchestrate orch.rollout \
  pillar='{"orch": {"lookup": {"rollout": {"tgt": "monitoring,homepage", "tgt_type": "list"}}}}'
```

## orch.push

Started by the reactor on `salt/fileserver/gitfs/update` with new commits, so about a minute
after a push to `main`. Not meant to be run by hand, though it can be (`salt-run state.orchestrate orch.push`).

1. `git_pillar.update`, because git_pillar polls on its own and may still be a commit behind.
2. Like `orch.rollout`, plus `push:enforce_check`: only minions that answer
   `salt-drift-check --enforce-allowed` with `yes` take part, which means enforce is on and its
   window is open (`formulas/salt-minion`). By day that is homepage, monitoring, forgejo and salt-master.
   Between 03:00 and 06:00 arrstack and jellyfin join. wazuh never does (no enforce). The rest
   stay with the drift check: `SaltDrift` (outside the window it is suppressed) and the nightly
   repair, or `/deploy`.
3. Dry run on all of them, then one at a time, salt-master last. The first failure stops it.

No lock between runs: two pushes a few minutes apart start two runs. They serialise per
minion (`queue`), and salt-master's own highstate (always last) may cut the other run short.
The next push or the hourly drift check catches up.

The drift check on those minions would apply the push within the hour anyway. This only makes
it immediate and ordered.

## Pillar id

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
