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

This is the pattern CLAUDE.md's "Established patterns" section already called out: NFS mounts are
runtime state of the guest, not a Proxmox/Tofu resource — express "this VM needs share X mounted
at path Y" as pillar data for that minion, consumed here.

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
