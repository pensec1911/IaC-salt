# openbao-snapshot formula

Nightly backup of OpenBao. OpenBao (.20) holds every secret the pillar resolves, isn't a minion,
and runs the integrated **Raft** storage (migrated from `file` on 2026-11-27, which had no
snapshot API). This formula runs on salt-master: it logs in with a dedicated AppRole, pulls
`sys/storage/raft/snapshot` and writes it to `/var/backups/openbao/openbao.snap`. salt-master's
own restic backup (`pillar/backup.sls`, 02:00, own repo password) carries it to the NAS, with
restic's retention as the snapshot history.

The snapshot is encrypted with OpenBao's barrier key and useless without the **unseal key**.
That key must never be backed up to the same place — it stays on the OpenBao host and in the
password manager.

## What it manages

- `/etc/openbao-snapshot` (0700) and a check that `secret-id` exists in it (0600, placed by hand).
- `/usr/local/sbin/openbao-snapshot` (Python, stdlib only): AppRole login → snapshot into
  `<file>.tmp` → gzip magic check → rename → token revoked. A failed run keeps the last good file.
- `openbao-snapshot.service` (oneshot, sandboxed) + `.timer`: daily 01:30 Europe/Berlin
  (+ ≤5 min), `Persistent`. That's before formulas/backup's 02:00 run.
- Metrics `openbao_snapshot_{success,bytes,duration_seconds,last_run_timestamp_seconds,
  last_success_timestamp_seconds}` in node-exporter's textfile dir; alerts
  `OpenBaoSnapshotFailed` / `OpenBaoSnapshotStale` (36 h) in `pillar/prometheus.sls`.
- Healthchecks ping `openbao-snapshot-<minion>` while `formulas/healthchecks-ping` has a key.

Pillar: `pillar/openbao-snapshot.sls` (`addr`, `role_id`); schema in `pillar.example.sls`,
defaults in `map.jinja`.

## Bootstrap (manual, one-time — security-critical)

On the OpenBao host as root (`BAO_ADDR`/`BAO_CACERT` are in root's `.bashrc`):

```sh
bao policy write openbao-snapshot - <<'EOF2'
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
EOF2
bao write auth/approle/role/openbao-snapshot \
  token_policies=openbao-snapshot token_ttl=10m token_max_ttl=15m \
  secret_id_bound_cidrs=192.168.178.28/32 token_bound_cidrs=192.168.178.28/32
bao read -field=role_id auth/approle/role/openbao-snapshot/role-id   # → pillar role_id
bao write -f -field=secret_id auth/approle/role/openbao-snapshot/secret-id
```

On salt-master, the `secret_id` without trailing newline:

```sh
sudo install -d -m 700 /etc/openbao-snapshot
sudo bash -c 'umask 077; printf %s "<secret_id>" > /etc/openbao-snapshot/secret-id'
```

The `secret_id` isn't backed up (regenerate it). Then apply salt-master and run
`systemctl start openbao-snapshot.service` once.

## Restore

From salt-master's restic repo (salt-master README "Backup and restore"), restore
`/var/backups/openbao/openbao.snap`, copy it to the OpenBao host, then on a running and unsealed
OpenBao (a fresh install needs `bao operator init` first, and the restore then replaces it):

```sh
bao operator raft snapshot restore -force openbao.snap
```

After the restore the **old** unseal key applies again. Old `file` backend copy from the
migration: `/root/openbao-file-2026-11-27.tgz` on the host (delete after a few days).
