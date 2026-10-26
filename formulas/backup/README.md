# backup formula

Nightly [restic](https://restic.net/) backup of the data Salt can't rebuild (app config and
databases under `/opt`, wazuh's keys and certs) into one repo per minion on the NAS. Images and
Salt-rendered config are reproducible and not backed up.

## What it manages

- `restic` package (Debian).
- `/etc/restic/password` (0600, from pillar, i.e. OpenBao `restic/repo`) and `/etc/restic/env`
  (`RESTIC_REPOSITORY=/mnt/backups/<minion>`, password file, cache dir).
- `/usr/local/sbin/restic-backup`: init the repo on first use → `restic backup` →
  `forget --prune` (default keep 7 daily / 4 weekly / 6 monthly) → `restic check` (structure,
  no data read) → node-exporter textfile metrics.
- `restic-backup.service` (oneshot, root, `RequiresMountsFor=/mnt/backups`) and
  `restic-backup.timer`: daily 02:00 Europe/Berlin + up to 10 min random delay, 45 min timeout, `Persistent`
  (a night missed while the VM was off runs at the next boot). That's before the 03:00
  enforce window of arrstack/jellyfin, so a self-repair never recreates a container mid-run.
- `stop_containers` are stopped before the run and started again afterwards (`ExecStopPost`,
  so also after a failure or timeout): the apps' SQLite databases aren't safe to copy while
  open. arrstack: ~1 min without Sonarr/Radarr/qBittorrent/…; gluetun stays up.

The share comes from `nfs-mount` (`nfs_mounts` entry `backups`, `nofail` +
`skip_required_by`: a refused export never keeps the VM or Docker from starting), so `nfs-mount` and
`node-exporter` (textfile directory) are listed before `backup` in `salt/top.sls`.

On monitoring the hourly enforce run can, in rare cases, start grafana again during the
~seconds it's stopped — the snapshot then still exists, the SQLite copy may just not be clean.

## Usage

```yaml
# salt/top.sls
'some-minion':
  - users
  - node-exporter
  - nfs-mount
  - some-service
  - backup
```

What each minion backs up: the map in `pillar/backup.sls`. Schema: `pillar.example.sls`.

## Metrics and alerts

`/var/lib/prometheus/node-exporter/backup.prom`:

| Metric | Meaning |
|---|---|
| `backup_success` | 1 = backup, forget and check all succeeded (restic exit 3 — some file unreadable — counts as failed) |
| `backup_last_success_timestamp_seconds` | last fully successful run; carried over on failure, 0 = never |
| `backup_last_run_timestamp_seconds` | last run, successful or not |
| `backup_duration_seconds` | duration of the last run (the container stop/start not included) |
| `backup_snapshot_bytes` / `backup_snapshot_files` / `backup_added_bytes` | from restic's backup summary, only after a success |

Alerts in `pillar/prometheus.sls`: `BackupFailed` (`backup_success == 0`), `BackupStale`
(no success for 36 h, also fires for a host that never succeeded). A run that never started
(unit failed on the mount) writes nothing — `BackupStale` catches it once metrics existed.

## NAS side (manual, one-time)

TrueNAS export `/mnt/pool01/backups` (dataset `pool01/backups`). The run is root on the
minion, and root is squashed by default — so writes fail with `Permission denied` until:

1. NAS user/group `restic` (3000:3000 — clients never see it by name).
2. Dataset root owned by it, mode `0700` — set with `chown`/`chmod` in the NAS shell; the
   Permissions dialog didn't apply it (2026-10-26).
3. NFS share, Advanced Options: **Maproot User/Group** = `restic` (root on a client writes as
   it). Mapall stays empty — it would map every client user, not just root.
4. Hosts: deliberately left open (`*`) so more minions can be added without a NAS change. Any
   LAN host's root can therefore write (and delete) as `restic` there; the repos are encrypted,
   but not protected from deletion.

Check from a minion: `sudo touch /mnt/backups/x && sudo rm /mnt/backups/x`.

## OpenBao (manual, one-time)

```sh
bao kv put -mount=homelab restic/repo password="$(openssl rand -base64 32)"
```

Keep a copy of that password **outside** the homelab (password manager): the backups exist
for the case where VMs — and maybe OpenBao — are gone. Without it the repos can't be read.

All four repos share this one password and all minions write to the same dataset as the same
NAS user, so root on any backup minion can read (and delete) every repo — incl. wazuh's CA key.
Per-minion passwords: change the sdb path in `pillar/backup.sls` to
`restic/{{ grains['id'] }}` — but see the next section for the existing repos.

## Changing the password

restic stores the repo key encrypted with the password; a new password in OpenBao alone
makes the next run fail (`wrong password`). Add the new one first, then remove the old:

```sh
set -a; . /etc/restic/env; set +a
restic key add            # enter the new password
restic key list           # note the old key's ID
# put the new password into OpenBao, highstate the minion, then:
restic key remove <old-id>
```

## Restore

On the minion, as root:

```sh
set -a; . /etc/restic/env; set +a
restic snapshots
restic ls latest /opt/arrstack/sonarr
docker stop sonarr
restic restore latest --target / --include /opt/arrstack/sonarr
docker start sonarr
```

Lost VM: Tofu re-creates it, the start reactor applies the highstate (share mounted, password
written, containers start with empty config). Then stop the containers, `restic restore latest
--target /`, start them. restic restores ownership and modes. `--host <minion>` selects the
old host's snapshots if the minion ID changed.

Run it now: `systemctl start restic-backup.service`, then
`journalctl -u restic-backup -n 50` and `cat /var/lib/prometheus/node-exporter/backup.prom`.
