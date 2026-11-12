# Pillar for formulas/backup. password and paths are required in practice;
# everything else has a working default (backup/map.jinja).
backup:
  lookup:
    # restic repo password — always an sdb reference, never a literal.
    # Changing it later locks the existing repos out (README).
    password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/repo?password') | yaml_encode }}
    # What to back up, and restic --exclude patterns.
    paths:
      - /opt/someapp
    excludes:
      - /opt/someapp/logs
    # Stopped for the run (SQLite DBs), started again afterwards.
    stop_containers:
      - someapp
    # Server DBs, dumped via `podman exec <container> <command>` (stdout ->
    # file) before restic runs. file must be inside paths; exclude the live
    # data dir. The container keeps running. format pg_custom = pg_dump -Fc,
    # header-checked by the restore test.
    dumps:
      - container: someapp-postgres
        command: [pg_dump, -U, someapp, -Fc, someapp]
        file: /opt/someapp/dump/someapp.pgdump
        format: pg_custom
    # restic forget --keep-<unit> <n> after each backup, then --prune.
    keep:
      daily: 7
      weekly: 4
      monthly: 6
    on_calendar: "*-*-* 02:00:00 Europe/Berlin"
    randomized_delay: 10min
    timeout: 45min
    # Repo = <repo_base>/<minion id>; repo_base is the mountpoint of the
    # nfs_mounts entry named mount_name.
    mount_name: backups
    repo_base: /mnt/backups
    config_dir: /etc/restic
    cache_dir: /var/cache/restic
    retry_lock: 10m
    unit: restic-backup
    script: /usr/local/sbin/restic-backup
    textfile_dir: /var/lib/prometheus/node-exporter
    metrics_file: backup.prom
    pkg: restic
    restic_bin: /usr/bin/restic
    podman_bin: /usr/bin/podman
    systemctl_bin: /usr/bin/systemctl
    python: /usr/bin/python3
    # Weekly restore test: check a sample of the pack data, restore the latest
    # snapshot into tmp_dir with --verify, integrity_check every SQLite file.
    restore_test:
      on_calendar: "Sun *-*-* 04:00:00 Europe/Berlin"
      randomized_delay: 30min
      timeout: 60min
      read_data_subset: 5%
      tmp_dir: /var/tmp
      min_free_bytes: 2147483648   # left free after the restore, else fail
      unit: restic-restore-test
      script: /usr/local/sbin/restic-restore-test
      metrics_file: restore-test.prom

# The share itself comes from formulas/nfs-mount.
nfs_mounts:
  - name: backups
    server: 192.168.178.10
    export: /mnt/pool01/backups
    mountpoint: /mnt/backups
    opts: [_netdev, rw, noatime, nofail]
    skip_required_by: true   # no container binds it
