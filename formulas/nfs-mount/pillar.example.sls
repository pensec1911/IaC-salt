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
    # systemd units that must wait for (and fail without) every mount below.
    # Set this for docker on any minion whose containers bind a share.
    required_by:
      - docker.service

# One entry per share this minion needs mounted.
nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
    # fstype: nfs4                    # optional, shown default
    # opts: [_netdev, rw, noatime]    # optional, shown default
    # skip_required_by: true          # optional: not part of required_by
