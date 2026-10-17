# jellyfin formula

Runs [Jellyfin](https://jellyfin.org) (`lscr.io/linuxserver/jellyfin`) as a Docker container,
serving the TrueNAS media share the arrstack fills. Depends on the `docker`, `users`, and
`nfs-mount` formulas — this formula only handles the container and its local dirs.

## What it manages

- `jellyfin.config` — `config_dir` and `cache_dir` (default `/opt/jellyfin/{config,cache}`),
  owned by the pinned `media` uid/gid. Both stay on local disk: `config` holds Jellyfin's SQLite
  library database, which doesn't belong on NFS.
- `jellyfin.container` — the container, publishing the WebUI on `http_port` (default 8096) and
  binding `media_mount` into the container at `/media` **read-only**. Metadata and artwork are
  stored in `config`, not next to the media, so Jellyfin never needs to write to the share.

The NFS mount itself is plain `nfs-mount` pillar data in `pillar/jellyfin.sls`, mounted `ro` on
this minion as well. Same share as the arrstack, same `media` account (uid/gid 970), so file
ownership lines up without any NAS-side change.

## Usage

```yaml
# salt/top.sls
'jellyfin':
  - users
  - nfs-mount
  - docker
  - jellyfin
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/jellyfin.sls`
(referenced from `pillar/top.sls`). Nothing here is secret: Jellyfin's admin account is created
in the first-run wizard, not via pillar.

## Not managed

- **Initial setup** — admin user, libraries (`/media/movies`, `/media/series`, `/media/music`)
  and their metadata settings are done once in the WebUI's first-run wizard and persist in
  `config_dir`.
- **Hardware transcoding** — the VM currently has no GPU passed through (only the emulated QEMU
  VGA, no `/dev/dri/renderD128`), so transcoding is software-only. If a GPU is passed through
  later, add it as a `devices:` entry on the container.
- **Client auto-discovery** (UDP 7359) and DLNA (UDP 1900) aren't published — clients connect via
  `http://<host>:8096` directly.
