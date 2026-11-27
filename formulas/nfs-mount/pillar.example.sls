# Optional overrides for formulas/nfs-mount, plus the mount list itself.
# See .claude/docs/patterns.md — NFS mounts are runtime state of
# the guest, expressed here as pillar data, not as a Proxmox/Tofu resource.
nfs-mount:
  lookup:
    default_fstype: nfs4
    default_opts:
      - _netdev
      - rw
      - noatime
    # Minutes a mount keeps trying at boot (NAS still starting); adds nofail,
    # retry=<n>, x-systemd.mount-timeout=<n+1>min to every mount. 0 = off.
    boot_wait_minutes: 15
    # systemd units that must wait for (and fail without) every mount below.
    # Units that use a share without declaring it. Not needed for
    # containers: Quadlet adds RequiresMountsFor= for their binds.
    required_by:
      - some-service.service

# One entry per share this minion needs mounted.
nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
    # fstype: nfs4                    # optional, shown default
    # opts: [_netdev, rw, noatime]    # optional, shown default
    # skip_required_by: true          # optional: not part of required_by
    # boot_wait_minutes: 15           # optional: overrides the lookup value
