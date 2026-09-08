# docker formula

Installs Docker Engine from Docker's official apt repo (Debian) and enables `python3-docker`,
which every state module in the `docker_*` family (`docker_container`, `docker_image`, ...)
needs on the minion to talk to the daemon.

Any formula that runs containers should `require: - sls: docker` rather than assuming Docker is
already present — don't duplicate installation logic per-service.

## Usage

Add `docker` to a minion's entry in `salt/top.sls`, before any formula that depends on it:

```yaml
'some-minion':
  - docker
  - some-service
```

## Pillar

None required. See `pillar.example.sls` for the (rarely-needed) overrides available under
`docker:lookup`.
