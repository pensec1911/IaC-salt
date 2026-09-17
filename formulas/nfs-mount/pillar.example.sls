# Optional overrides for formulas/nfs-mount, plus the mount list itself.
# See CLAUDE.md "Established patterns" — NFS mounts are runtime state of
# the guest, expressed here as pillar data, not as a Proxmox/Tofu resource.
nfs-mount:
  lookup:
    default_fstype: nfs4
    default_opts:
      - _netdev
      - rw
      - noatime

# One entry per share this minion needs mounted.
nfs_mounts:
  - name: media
    server: 192.168.178.10
    export: /mnt/pool01/media
    mountpoint: /mnt/media
    # fstype: nfs4                    # optional, shown default
    # opts: [_netdev, rw, noatime]    # optional, shown default
