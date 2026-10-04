# docker formula

Installs Docker Engine from Docker's official apt repo (Debian), plus what Salt itself needs to
manage containers: the `saltext.dockermod` extension and the `docker` Python library, installed
into Salt's onedir Python via `salt-pip`.

Docker support is no longer in Salt core (moved out in 3007). Without the extension every
`docker_container`/`docker_image` state fails with `'docker_container.running' is not available`.
The distro's `python3-docker` doesn't help — the onedir Salt can't import system packages.

On a fresh minion a `test=True` run still reports that error for the consuming formulas'
container states: the extension only gets installed during the real apply.

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
