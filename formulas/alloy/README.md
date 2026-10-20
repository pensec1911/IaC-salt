# alloy formula

Runs [Grafana Alloy](https://github.com/grafana/alloy) (`grafana/alloy`) as a Docker container on
a docker host and ships its logs to Loki (`formulas/loki`). Depends on the `docker` formula.

## What it ships

| Source | Labels |
|---|---|
| Every container's stdout/stderr, via the docker API | `job="docker"`, `container=<name>` |
| The host's systemd journal (`/var/log/journal`) — systemd units, salt-minion, NFS, kernel | `job="journal"`, `unit=<systemd unit>`, `level=<priority>` |

Plus `host=<minion id>` on everything. A fresh Alloy reads the journal back `journal_max_age`
(12h); positions are kept in `data_dir` on the host, so a recreated container neither re-ships nor
skips.

## What it manages

- `alloy.config` — `config.alloy` in `config_dir`, `data_dir` for positions.
- `alloy.container` — the container, root inside (docker socket + journal; the socket is
  root-equivalent anyway), docker socket / journal / `/etc/machine-id` bound read-only. No
  published port: the debug UI (:12345) stays inside the container. Restarts when the config
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
  (self-repair), on arrstack/jellyfin at the next manual apply or reboot. Not added as
  consumers on purpose: a mine change would then highstate arrstack/jellyfin, which are
  report-only.

## Usage

Every docker host, after `docker`:

```yaml
# salt/top.sls
'some-minion':
  - docker
  - cadvisor
  - alloy
```

## Pillar

None required. See `pillar.example.sls`.
