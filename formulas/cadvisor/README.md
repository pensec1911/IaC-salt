# cadvisor formula

Runs [cAdvisor](https://github.com/google/cadvisor) as a Podman container (Quadlet unit via `formulas/podman`): per-container CPU,
memory, network and I/O metrics on `:<host_port>/metrics` (default 8088) for Prometheus.
Depends on the `podman` formula.

## What it manages

- `cadvisor.container` — raw-cgroup mode: no container runtime API (the Podman socket would be
  root-equivalent), not privileged, own user namespace, no capabilities, read-only root.
  `--cgroupns=host` plus read-only binds of `/`, `/sys`, `/sys/fs/cgroup`, `/dev/disk`,
  `/etc/machine-id`. It reports every cgroup under `raw_cgroup_prefixes` (`/system.slice/`);
  `--docker_only=true` keeps everything else out (the runtime factories just fail to register —
  harmless lines at start). A container is `id="/system.slice/<name>.service/libpod-payload-<id>"`;
  Prometheus derives `name=<container>` from that (`metric_relabel_configs` on the `cadvisor`
  job, `pillar/prometheus.sls`). No `image` label any more — nothing used it.
- `cadvisor.mine` — Salt Mine entry `cadvisor` (`network.ip_addrs` on `eth0`) in
  `/etc/salt/minion.d/mine-cadvisor.conf`, pushed once via `mine.update` when that file changes.
  `formulas/prometheus` builds its `cadvisor` scrape job from `mine.get('*', 'cadvisor')`, so a new
  minion with this formula gets scraped without editing `pillar/prometheus.sls`.

No host user, no state on disk.

## Usage

Every container host, after `podman`:

```yaml
# salt/top.sls
'some-minion':
  - podman
  - cadvisor
  - some-service
```

Prometheus picks the host up on its own: when the mine conf is first written, the state fires
`homelab/mine/updated` and the master's reactor re-applies `monitoring` (`mine_consumers` in
`formulas/salt-master`). Dropping the formula from a minion leaves its mine entry
behind — clear it with `salt '<minion>' mine.delete cadvisor`.

## Pillar

None required. See `pillar.example.sls`.
