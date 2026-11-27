# backup-offsite formula

Nightly offsite copy of every restic repo on the NAS. `formulas/backup` writes one repo per
minion to `/mnt/backups/<minion>`; losing the NAS (or the house) would take the data and its
backups together. This formula runs on salt-master, which mounts the whole share, and
`restic copy`s each repo into its own repo in the private OCI bucket `homelab-restic`
(IaC-opentofu `oci/offsite.tf`, Always Free: 20 GB).

salt-master resolves every pillar secret anyway, so the source repo passwords it holds for
this add no exposure. The offsite repos have their **own** password, independent of the NAS
repos — see "Bootstrap" for why it must also live outside the homelab.

## What it manages

- `/etc/restic-offsite/` (0700): `password` (offsite repos), `sources/default` +
  `sources/<minion>` (NAS repo passwords; per-minion overrides mirror `password_path` in
  `pillar/backup.sls`), `env` (repo base, S3 credentials, region) — all 0600, never in state
  output.
- `/usr/local/sbin/restic-offsite`: for every directory under `/mnt/backups` that holds a
  restic repo → init the offsite repo on first use (`--copy-chunker-params`, so copies
  deduplicate) → `restic copy` → `forget --prune` (7 daily / 4 weekly / 12 monthly) →
  `check` (structure) → `stats`. A failing repo doesn't stop the others; a new minion goes
  offsite without a change here.
- `restic-offsite.service` (oneshot, sandboxed, `RequiresMountsFor=/mnt/backups`) + `.timer`:
  daily 03:15 Europe/Berlin (+ ≤10 min), after every nightly backup and before the Sunday
  restore test, `Persistent`.
- Metrics `backup_offsite_{success,last_success_timestamp_seconds,repo_bytes}{repo=…}`,
  `backup_offsite_{run_success,duration_seconds,last_run_timestamp_seconds}` in
  `backup_offsite.prom`; alerts `OffsiteCopyFailed`, `OffsiteCopyStale` (36 h, also for a repo
  that never made it), `OffsiteNearFreeTier` (> 15 GB) in `pillar/prometheus.sls`.
- Healthchecks ping `backup-offsite-<minion>` while `formulas/healthchecks-ping` has a key.

Pillar: `pillar/backup-offsite.sls`; schema in `pillar.example.sls`, defaults in `map.jinja`.
Requires `backup` (restic, the share) and `node-exporter` before it in `salt/top.sls`.

## Bootstrap (manual, one-time — security-critical)

1. OCI side (bucket via Tofu, IAM user/group/policy and Customer Secret Key by hand):
   IaC-opentofu README "Offsite-Bucket (restic)". `repository` in pillar =
   `tofu -chdir=oci output restic_offsite_repository`.
2. On the OpenBao host as root — the offsite password generated there, the S3 key pasted:

   ```sh
   read -rs -p 'access key id: ' AK; echo; read -rs -p 'secret key: ' SK; echo
   bao kv put -mount=homelab restic/offsite password="$(openssl rand -base64 32)" \
     access_key_id="$AK" secret_access_key="$SK"; unset AK SK
   bao kv get -field=password -mount=homelab restic/offsite   # → password manager
   ```

3. **Put the offsite password into the password manager.** With NAS and OpenBao both gone it
   is the only key to the copy (OpenBao's own snapshot is in there, encrypted with the barrier
   key — so the OpenBao unseal key belongs there too). The S3 key can be regenerated in the
   OCI console.
4. Apply salt-master, then `systemctl start restic-offsite.service` once (first run uploads
   everything, < 1 GB) and check `journalctl -u restic-offsite` and `backup_offsite.prom`.

## Restore

On salt-master (or any host with restic, the env values and the password), as root:

```sh
set -a; . /etc/restic-offsite/env; set +a
export RESTIC_REPOSITORY=$RESTIC_OFFSITE_BASE/<minion>
restic -o s3.bucket-lookup=path snapshots
restic -o s3.bucket-lookup=path restore latest --target /tmp/restore --include <path>
```

Without salt-master: write the four values (`RESTIC_PASSWORD` from the password manager, a
fresh Customer Secret Key, `AWS_DEFAULT_REGION`, the repo URL) by hand. Back to the NAS: `restic
copy` the other way (`-r /mnt/backups/<minion> copy --from-repo s3:…`), then restore there as
in `formulas/backup` README.

## Limits

- Only a structural `check` per night — no data is read back from OCI yet. A periodic
  `check --read-data-subset` / restore test on the offsite repos is a follow-up.
- The S3 key may delete objects (`forget --prune` needs it): root on salt-master can wipe the
  copy. Append-only/immutable storage is the roadmap item "rest-server append-only".
