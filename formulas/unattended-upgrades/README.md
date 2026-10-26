# unattended-upgrades formula

OS patching for every minion. Debian's `unattended-upgrades` installs updates from **Debian
main (point releases) and Debian-Security** daily — the Debian 13 cloud image already ships it
enabled; this formula pins that state down and adds metrics + alerts.

- `pkg.installed unattended-upgrades`; `apt-daily.timer` (package lists) and
  `apt-daily-upgrade.timer` (the u-u run, ~06:00 UTC + random delay) enabled.
- Drop-in `/etc/apt/apt.conf.d/52unattended-upgrades-salt`, read after the shipped
  `20auto-upgrades` / `50unattended-upgrades` (both stay untouched): periodic switches on,
  `Automatic-Reboot "false"`, remove unused kernels, optional `Package-Blacklist`.
- `os-patch-metrics.timer` (hourly + 2 min after boot) → `/usr/local/sbin/os-patch-metrics`
  writes `/var/lib/prometheus/node-exporter/os_patch.prom`.

**Third-party repos are not patched unattended.** The shipped `Origins-Pattern` only matches
Debian, so `docker-ce`/`containerd.io` (Docker repo), `salt-minion` (Artifactory) and
`wazuh-agent`/`wazuh-*` (Wazuh repo) only change when bumped deliberately — the agent has to
match the manager's version, a containerd upgrade restarts every container.

**u-u itself never reboots.** A kernel/libc upgrade leaves `/run/reboot-required` (Debian's
`/etc/kernel/postinst.d/unattended-upgrades` hook, packages in `/run/reboot-required.pkgs`);
the master's nightly rolling reboot (`formulas/orch`, 03:15 Berlin, one minion at a time)
picks it up. `RebootRequired` fires after 26 h, i.e. only when that run didn't. `automatic_reboot:
True` per minion in pillar would switch that minion to u-u's own uncoordinated reboot at
`automatic_reboot_time` — not used.

## Usage

```yaml
# salt/top.sls — every minion, after node-exporter (writes into its textfile directory)
'some-minion':
  - node-exporter
  - unattended-upgrades
```

## Pillar

None needed. Schema: `pillar.example.sls`.

## Metrics and alerts

| Metric | Meaning |
|---|---|
| `os_reboot_required` (+ `_since_timestamp_seconds`) | `/run/reboot-required` exists |
| `os_upgrades_pending` | `apt-get -s dist-upgrade` count, all repos (incl. the deliberately pinned ones) |
| `os_security_upgrades_pending` | the same, Debian-Security only |
| `os_unattended_upgrade_last_run_timestamp_seconds` | mtime of `/var/lib/apt/periodic/unattended-upgrades-stamp` |
| `os_apt_lists_updated_timestamp_seconds` | mtime of `/var/lib/apt/periodic/update-stamp` (apt-daily) — the pending counts are only as fresh as the lists |
| `os_patch_metrics_success`, `os_patch_metrics_last_run_timestamp_seconds` | the script itself |

Alerts in `pillar/prometheus.sls`: `RebootRequired` (26 h), `SecurityUpgradesPending` (> 0
for 48 h — u-u should have installed them; held/blacklisted package or failing run),
`UnattendedUpgradeStale` (no run for 3 days), `AptListsStale` (lists not updated for 3 days),
`PatchMetricsStale`.

## Checks

- `cat /var/lib/prometheus/node-exporter/os_patch.prom`
- `sudo unattended-upgrade --dry-run --debug` — allowed origins, what it would install.
- `apt-config dump | grep -i unattended` — effective settings after the drop-in.
- `less /var/log/unattended-upgrades/unattended-upgrades.log`, `cat /run/reboot-required.pkgs`.
