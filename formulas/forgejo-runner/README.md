# forgejo-runner formula

Runs a [Forgejo Runner](https://forgejo.org/docs/latest/admin/actions/)
(`data.forgejo.org/forgejo/runner`) for Forgejo Actions, with its own Docker-in-Docker sidecar
for the job containers. Depends on the `docker` and `users` formulas. The Forgejo side of the
registration is `forgejo:lookup:runners` (formulas/forgejo).

## What it manages

- `forgejo-runner.config` — `data_dir` (0700, pinned `forgejo-runner` account 973:973) with
  `config.yml` (from `files/config.yml.j2`) and `token` (the registration secret, 0600, read via
  `token_url`), and `dind_dir` for dind's `/var/lib/docker`.
- `forgejo-runner.container` — a private docker network, the dind container (privileged,
  `dockerd` on plain TCP `dind_port`, reachable only on that network) and the runner container
  (`DOCKER_HOST` = dind), restarted when config or token change.

## Isolation

Jobs run inside dind, not on the VM's Docker daemon, so a workflow can't reach the host socket
and can't stop or alter the Forgejo container — the deploy source of the whole homelab. Job
containers aren't privileged, get no docker socket (`docker_host: "-"`), no volumes, and a fresh
network per job. dind itself has to be privileged. The runner is registered for the `homelab`
org only, so it never picks up jobs from other owners. Jobs can still reach the LAN like any
host on it.

## Registration

Offline registration with a shared 40-hex secret (OpenBao `forgejo/runner`, key `secret`):
formulas/forgejo runs `forgejo-cli actions register` with it (again only when it changes), and
this formula derives the runner's uuid from its first 16 chars and uses the whole secret as the
token (forgejo.org docs "Offline registration"). Nothing to click. To rotate, change the last 24
chars in OpenBao and apply forgejo. A missing or malformed secret fails the state. Order on a
fresh Forgejo: install wizard → the `homelab` org → apply (registration waits for the wizard and
fails while the org is missing).

## Pillar

See `pillar.example.sls`. Real values live in `pillar/forgejo.sls`.

## Backup

None needed: config and token come from Salt/OpenBao, `dind_dir` is only an image cache, and job
logs are stored by Forgejo (backed up with it).
