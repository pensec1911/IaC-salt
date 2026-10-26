---
name: homelab-status
description: Use when asked whether the homelab is healthy ("ist alles ok?", status, what's broken), after a deploy, or before starting risky work. Read-only summary of firing alerts, Salt drift, backups, restore tests, pending patches/reboots and failed UI probes, straight from Prometheus/Alertmanager on monitoring.
---

# Homelab status

```sh
python3 .claude/skills/homelab-status/status.py            # everything
python3 .claude/skills/homelab-status/status.py arrstack   # one minion
```

Queries `http://192.168.178.25:9090` (Prometheus) and `:9093` (Alertmanager) directly — no SSH,
nothing written. Exit 0 = all good, 1 = something needs a look, 2 = monitoring unreachable.

## Reading it

- **drift `Np/Mf`**: N states would change, M fail on a highstate dry run. Expected for a few
  minutes after a push until the hourly check, and on arrstack/jellyfin until the 03:00–06:00
  enforce window. Details: `ssh salt-master "sudo salt <minion> state.apply test=True"` —
  then `/deploy <minion>` (git is right) or commit what the VM has (VM is right).
- **backup / restore**: `ok`/`FAIL` + age of the last success. `-` = minion doesn't back up
  (no state to keep). Stale > 36 h / 8 d alerts on its own (formulas/backup README).
- **patches**: pending security upgrades are normal until the next daily u-u run; `reboot` is
  manual (`RebootRequired`).
- **Failed UI probes**: homepage items whose URL doesn't answer (blackbox, `ProbeFailed`).
- Monitoring unreachable → the monitoring VM itself is the problem; check with
  `ssh salt-master "sudo salt monitoring test.ping"`.

Report in a few lines: what's red, likely cause, suggested next step. Don't fix anything
without being asked.
