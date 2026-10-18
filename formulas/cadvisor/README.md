# cadvisor formula

Runs [cAdvisor](https://github.com/google/cadvisor) as a Docker container: per-container CPU,
memory, network and I/O metrics on `:<host_port>/metrics` (default 8088) for Prometheus.
Depends on the `docker` formula.

## What it manages

- `cadvisor.container` — privileged container with the read-only host binds cAdvisor needs
  (`/`, `/var/run`, `/sys`, `/var/lib/docker`, `/dev/disk`, `/dev/kmsg`). `--docker_only` keeps
  it to Docker containers (no per-systemd-unit series).
- `cadvisor.mine` — Salt Mine entry `cadvisor` (`network.ip_addrs` on `eth0`) in
  `/etc/salt/minion.d/mine-cadvisor.conf`, pushed once via `mine.update` when that file changes.
  `formulas/prometheus` builds its `cadvisor` scrape job from `mine.get('*', 'cadvisor')`, so a new
  minion with this formula gets scraped without editing `pillar/prometheus.sls`.

No host user, no state on disk.

## Usage

Every minion that runs `docker`, after it:

```yaml
# salt/top.sls
'some-minion':
  - docker
  - cadvisor
  - some-service
```

Prometheus picks the host up on its own: when the mine conf is first written, the state fires
`homelab/mine/updated` and the master's reactor re-applies `monitoring` (`mine_consumers` in
`formulas/salt-master`). Dropping the formula from a minion leaves its mine entry
behind — clear it with `salt '<minion>' mine.delete cadvisor`.

## Pillar

None required. See `pillar.example.sls`.
