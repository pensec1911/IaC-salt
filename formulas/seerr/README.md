# seerr formula

Runs [Seerr](https://github.com/seerr-team/seerr) (`ghcr.io/seerr-team/seerr`) as a Docker
container. Users request movies and series there, and Seerr passes them on to Sonarr/Radarr.
Seerr is the merged successor of Jellyseerr and Overseerr (both archived). Depends on the
`docker` and `users` formulas.

## What it manages

- `seerr.config` — `config_dir` (default `/opt/seerr/config`), owned by the pinned `seerr`
  uid/gid, mode 0750. It stays on local disk because it holds Seerr's SQLite DB and
  `settings.json`.
- `seerr.container` — the container, publishing the WebUI on `http_port` (default 5055). It
  runs on the normal Docker bridge, **not** behind gluetun: Seerr only talks to TMDB and the LAN.

## Dedicated user

The image runs as `node` (uid 1000) by default, which is the range of the per-minion `GLOBAL`
login account. So the container gets a `user: 971:971` override. The `seerr` system account
(971:971, pinned in `pillar/seerr.sls`) comes from the shared `users` formula.

## Usage

```yaml
# salt/top.sls
'arrstack':
  - users
  - docker
  - seerr
```

## Pillar

See `pillar.example.sls`. Real values live in `pillar/seerr.sls`. Nothing in it is secret.

## Not managed

- **Initial setup**: the first-run wizard in the WebUI. Choose Jellyfin
  (`http://192.168.178.24:8096`) and sign in with a Jellyfin admin. Then add Sonarr/Radarr with
  their API keys, using `http://192.168.178.22:8989` / `:7878`. Those ports are published by
  gluetun on the host, so use the host IP, not `localhost` (`localhost` is the Seerr container
  itself). Everything persists in `config_dir/settings.json`. The API keys never go through
  pillar.
- **Migration from Jellyseerr**: none was deployed here. If you bring an old `config` dir, copy
  it into `config_dir` before the first start and `chown -R 971:971` it.
