# grafana formula

Runs [grafana/grafana-oss](https://hub.docker.com/r/grafana/grafana-oss) as a Podman container (Quadlet unit via `formulas/podman`).
Depends on the `podman` formula (runtime and container macro) — this formula only handles the container
and its data dir.

## What it manages

- `grafana.config` — creates `data_dir` (persistent state: sqlite db, plugins), renders the
  datasource provisioning file (`grafana:datasources`) and a file-based dashboard provider, and
  downloads the pinned grafana.com dashboards (`grafana:dashboards`, sha256-checked) into
  `dashboards_dir`.
- `grafana.container` — runs the container via the `formulas/podman` macro (Quadlet unit `grafana`), bind-mounting
  `data_dir` to `/var/lib/grafana`. Admin credentials come in via `GF_SECURITY_ADMIN_USER`/
  `GF_SECURITY_ADMIN_PASSWORD` env vars. Only `provisioning/datasources` and
  `provisioning/dashboards` are bind-mounted (the image's other provisioning dirs stay), and the
  container restarts when either provisioning file changes — Grafana reads them only at start.
  Dashboard JSON changes are picked up without a restart (provider polls every 60s).

No dedicated host user (`users` formula) is created for this. The official image already runs
internally as a fixed user, uid `472` ("grafana") — `data_dir` is numeric-owned (`472:472`)
directly to match, and the container's `user:` param is set the same way, so no `/etc/passwd`
entry is needed for the bind mount to work.

Provisioned dashboards are read-only in the UI (`allowUiUpdates: false`): to customise one, use
"Save as" into another folder. Only dashboards that select their datasource via a datasource
variable work as-is — grafana.com exports that rely on `__inputs` (import-time `${DS_…}`
substitution) don't resolve under file provisioning.

## Usage

```yaml
# salt/top.sls
'monitoring':
  - users
  - podman
  - grafana
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/grafana.sls`
(referenced from `pillar/top.sls`).

`admin_password` is required in practice (see `map.jinja` — no sane default) and must be an
`sdb://` reference, never a literal value (.claude/docs/secrets.md). **Important quirk**:
Grafana only applies `GF_SECURITY_ADMIN_PASSWORD` the first time the container starts against an
empty database — changing the pillar value later does not rotate an already-provisioned admin
password. If it drifts, reset it via `podman exec grafana grafana-cli admin reset-admin-password
<new>` rather than expecting a pillar change + `state.apply` to fix it.
