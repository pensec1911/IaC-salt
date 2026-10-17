# cadvisor formula

Runs [cAdvisor](https://github.com/google/cadvisor) as a Docker container: per-container CPU,
memory, network and I/O metrics on `:<host_port>/metrics` (default 8088) for Prometheus.
Depends on the `docker` formula.

## What it manages

- `cadvisor.container` — privileged container with the read-only host binds cAdvisor needs
  (`/`, `/var/run`, `/sys`, `/var/lib/docker`, `/dev/disk`, `/dev/kmsg`). `--docker_only` keeps
  it to Docker containers (no per-systemd-unit series).

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

Then add the host as a target of the `cadvisor` job in `pillar/prometheus.sls`.

## Pillar

None required. See `pillar.example.sls`.
