# grafana formula

Runs [grafana/grafana-oss](https://hub.docker.com/r/grafana/grafana-oss) as a Docker container.
Depends on the `docker` formula (installs the engine) — this formula only handles the container
and its data dir.

## What it manages

- `grafana.config` — creates `data_dir` (persistent state: sqlite db, dashboards, plugins).
- `grafana.container` — runs the container via `docker_container.running`, bind-mounting
  `data_dir` to `/var/lib/grafana`. Admin credentials come in via `GF_SECURITY_ADMIN_USER`/
  `GF_SECURITY_ADMIN_PASSWORD` env vars.

No dedicated host user (`users` formula) is created for this. The official image already runs
internally as a fixed user, uid `472` ("grafana") — `data_dir` is numeric-owned (`472:472`)
directly to match, and the container's `user:` param is set the same way, so no `/etc/passwd`
entry is needed for the bind mount to work.

No provisioning (dashboards/datasources-as-code) is wired up yet — this only gets the container
running with a persistent data dir and an admin login. Add a `provisioning/` bind mount + pillar
schema the same way `prometheus.yml` is templated if/when that's needed.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - users
  - docker
  - grafana
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/grafana.sls`
(referenced from `pillar/top.sls`).

`admin_password` is required in practice (see `map.jinja` — no sane default) and must be an
`sdb://` reference, never a literal value (CLAUDE.md "Secrets in pillar"). **Important quirk**:
Grafana only applies `GF_SECURITY_ADMIN_PASSWORD` the first time the container starts against an
empty database — changing the pillar value later does not rotate an already-provisioned admin
password. If it drifts, reset it via `docker exec grafana grafana-cli admin reset-admin-password
<new>` rather than expecting a pillar change + `state.apply` to fix it.
