# homepage formula

Runs [gethomepage/homepage](https://github.com/gethomepage/homepage) as a Podman container (Quadlet unit via `formulas/podman`).
Depends on the `podman` formula (runtime and container macro) — this formula only handles the
container and its config.

## What it manages

- `homepage.config` — renders `settings.yaml` and `services.yaml` into
  `homepage:lookup:config_dir` (default `/opt/homepage/config`) from pillar data via
  `files/*.yaml.j2`, root-owned.
- `homepage.container` — the container via the `formulas/podman` macro (Quadlet unit
  `homepage`): runs as `puid:pgid` directly (no `PUID` env, so the image's entrypoint needs no
  capabilities), read-only root. `/app/config` is a tmpfs; the two rendered files are bound
  read-only into it and the image copies its other skeleton files in on start, so nothing on
  the host is written. Logs to stdout (journal). Restarts when the rendered config changes.

Per service item, `services.yaml.j2` passes through `href`, `description`, `icon`, `ping` and
`widget` (any nesting, rendered as JSON). `siteMonitor` (the status dot) defaults to the item's
`href`; set `siteMonitor: false` to drop it or a URL to probe something else. Widgets that need
credentials must get them via `sdb.get` in pillar like any other secret.

Only `settings.yaml` and `services.yaml` are templated for now — `widgets.yaml`/`bookmarks.yaml`
aren't wired up since nothing needs them yet; add a template + pillar key the same way
`services.yaml` is done if that changes.

## Usage

```yaml
# salt/top.sls
'homepage':
  - podman
  - homepage
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/homepage.sls`
(referenced from `pillar/top.sls`) — edit that file to change what shows up on the dashboard, no
need to touch anything under `salt/`.
