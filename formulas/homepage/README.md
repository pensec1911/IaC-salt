# homepage formula

Runs [gethomepage/homepage](https://github.com/gethomepage/homepage) as a Docker container.
Depends on the `docker` formula (installs the engine) — this formula only handles the
container and its config.

## What it manages

- `homepage.config` — renders `settings.yaml` and `services.yaml` into
  `homepage:lookup:config_dir` (default `/opt/homepage/config`) from pillar data via
  `files/*.yaml.j2`.
- `homepage.container` — runs the container via `docker_container.running`, bind-mounting the
  config dir. Restarts automatically when the rendered config changes (`watch`).

Only `settings.yaml` and `services.yaml` are templated for now — `widgets.yaml`/`bookmarks.yaml`
aren't wired up since nothing needs them yet; add a template + pillar key the same way
`services.yaml` is done if that changes.

## Usage

```yaml
# salt/top.sls
'homepage':
  - docker
  - homepage
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/homepage.sls`
(referenced from `pillar/top.sls`) — edit that file to change what shows up on the dashboard, no
need to touch anything under `salt/`.
