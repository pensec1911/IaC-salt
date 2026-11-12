# alloy formula

Runs [Grafana Alloy](https://github.com/grafana/alloy) (`docker.io/grafana/alloy`) as a Podman
container (Quadlet unit via `formulas/podman`) on a container host and ships the host journal —
container logs included — to Loki (`formulas/loki`). Depends on the `podman` formula.

## What it ships

| Source | Labels |
|---|---|
| Container stdout/stderr — Podman's journald log driver, journal entries with `CONTAINER_NAME` | `job="container"`, `container=<name>`, `unit=<name>.service`, `level` |
| Everything else in the host journal (`/var/log/journal`) — systemd units, salt-minion, NFS, kernel | `job="journal"`, `unit=<systemd unit>`, `level=<priority>` |

Until the Podman migration (2026-11) container logs came via the docker API as `job="docker"`;
older data in Loki keeps that label. `{container="x"}` finds both.

Plus `host=<minion id>` on everything. A fresh Alloy reads the journal back `journal_max_age`
(12h); positions are kept in `data_dir` on the host, so a recreated container neither re-ships nor
skips.

## What it manages

- `alloy.config` — `config.alloy` in `config_dir`, `data_dir` for positions.
- `alloy.container` — the container, root inside its own user namespace (a sub-UID on the host),
  no capabilities. Reads the journal through the host's `systemd-journal` group, mapped 1:1 and
  added as a supplementary group (`journal_group`, gid looked up at render time). Journal and
  `/etc/machine-id` bound read-only; `data_dir` handed to the container with `:U` and bound at
  `/alloy-data` (the image's `/var/lib/alloy` is 0770 for uid 473, which root without
  `DAC_OVERRIDE` can't traverse). No published port: the debug UI (:12345) stays inside the container. Restarts when the config
  changes. Normal bridge network on arrstack too, not behind gluetun.

## Finding Loki

The push URL is built from the Salt Mine entry `loki` that `formulas/loki` publishes
(`http://<ip>:<loki_port>`), rendered when this minion's highstate runs.

- No Loki in the mine yet: the run shows `alloy-waiting-for-loki` and deploys nothing. Apply the
  Loki minion (monitoring) first, then this one.
- On monitoring itself the first run always waits (the template renders before `loki.mine`
  runs); the mine event's reactor re-applies monitoring right after, which deploys Alloy.
- Only monitoring is a mine consumer (`salt-master:lookup:mine_consumers`). If Loki ever moves,
  the other hosts pick up the new address on their next highstate — hourly on homepage
  (self-repair), on arrstack/jellyfin in the next night's self-repair window (03:00–06:00).
  Not added as consumers on purpose: a mine change would then highstate arrstack/jellyfin
  during the day, which they only allow at night.

## Usage

Every container host, after `podman`:

```yaml
# salt/top.sls
'some-minion':
  - podman
  - cadvisor
  - alloy
```

## Pillar

None required. See `pillar.example.sls`.
