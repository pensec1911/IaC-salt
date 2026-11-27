# nfs-mount formula

Generic, pillar-driven NFS mount management. Nothing here is service- or minion-specific — every
mount it manages comes entirely from `pillar:nfs_mounts`.

## What it manages

Installs `nfs-common` (the client package `mount.mounted` needs for `fstype: nfs4`), then loops
over `nfs_mounts` (a list of dicts) and emits one `mount.mounted` state per entry, with a fixed,
predictable state ID: `nfs-mount-<name>`. `mkmnt: True` creates the local mountpoint directory if
missing; `persist: True` writes an `/etc/fstab` entry so it survives reboots.

A service formula that needs a share mounted doesn't mount it itself — it declares
`require: - mount: nfs-mount-<name>` in the states that bind that path, and the minion's
`salt/top.sls` entry lists `nfs-mount` before it. See `formulas/arrstack` for an example.

This is the pattern .claude/docs/patterns.md already called out: NFS mounts are
runtime state of the guest, not a Proxmox/Tofu resource — express "this VM needs share X mounted
at path Y" as pillar data for that minion, consumed here.

`nfs-mount:lookup:required_by` (list of systemd units, default empty) adds a drop-in with
`RequiresMountsFor=<every mountpoint>` to each listed unit (+ `daemon-reload`), for units that
use a share but don't declare it themselves. Containers don't need it: Quadlet adds
`RequiresMountsFor=` for every bound path to the container's unit (`formulas/podman`), so a
container that binds a share waits for it at boot and fails instead of running on the empty
mountpoint. Takes effect on the unit's next start — Salt doesn't restart it.
A mount entry with `skip_required_by: true` stays out of that drop-in (the backup share).

### Cold start: waiting for the NAS

When the whole lab powers on, the VMs boot faster than TrueNAS serves NFS. Before this was
handled, systemd killed every mount after its 90 s default (`Mounting timed out`) and the
containers bound to them failed for good (2026-11-26). So every mount gets, on top of its
`opts`:

- `nofail`: boot (and `remote-fs.target`, so logins) never waits for the NAS.
- `retry=15`: `mount.nfs` keeps trying in the foreground for 15 minutes.
- `x-systemd.mount-timeout=16min`: systemd doesn't kill the mount before that.

Units that need the share wait for it via `RequiresMountsFor=` (Quadlet or `required_by`) and
start as soon as the NAS answers. If the NAS takes longer than 15 minutes, the mount and those
units still fail: `mount -a -t nfs4`, then `state.apply`. Window: `nfs-mount:lookup:boot_wait_minutes`
(default 15) or `boot_wait_minutes` per `nfs_mounts` entry; `0` leaves the options as given.
Salt treats all three options as invisible, so changing them never remounts a live share; a
changed fstab gets a `daemon-reload`.

## Usage

```yaml
# salt/top.sls
'some-minion':
  - users
  - nfs-mount
  - some-service
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/<consuming-purpose>.sls`
(e.g. `pillar/nfs-mount.sls` for the `arrstack` minion's share) — this formula has no pillar file
of its own the way `homepage` does, since the mount list naturally belongs with whichever pillar
file documents the minion that needs it.

Nothing here is a secret — an NFS export path/server isn't a credential, so this pillar data is
plain, not `sdb://`-referenced.
