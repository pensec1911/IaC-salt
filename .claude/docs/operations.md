# Operations

All `salt` commands run on the master (`ssh salt-master`, then `sudo salt …`). Note
`sudo salt '<minion>' …` — a bare `sudo salt-master …` starts a second master daemon.

## Deploy a change

```sh
# after git push
salt-run fileserver.update             # states (else wait ≤60 s for the gitfs poll)
salt-run git_pillar.update             # pillar
salt '<minion>' saltutil.refresh_pillar
salt '<minion>' state.apply test=True  # always dry-run first
salt '<minion>' state.apply
```

- Use a **full** `state.apply` on the minion, not `state.apply <formula>`, for formulas whose
  requisites come from other formulas (`users`, `docker`, `nfs-mount`) — otherwise
  "Referenced state does not exist for requisite".
- In `test=True` on a fresh minion, `docker_container.running` reports
  "'docker_container.running' is not available" — expected, the docker Python module isn't
  installed until the real run.
- Recreating gluetun restarts every attached arrstack container (by design, via `watch`).

## Reactor

A minion starting (Tofu provision, reboot, `salt-minion` restart) triggers a full
`state.apply` on it via the master's reactor (`formulas/salt-master`). So a reboot means a
highstate a few seconds later; check it with `salt-run jobs.list_jobs search_function=state.apply`.

A stopped `docker` on a docker host (down > 90 s, i.e. systemd gave up or someone stopped it)
is started again via the service beacon → reactor (`formulas/salt-minion` "Beacons"). Pausing
for maintenance: `salt '<minion>' beacons.disable_beacon service`.

## Drift check

Every minion dry-runs its highstate hourly (`formulas/salt-minion`) and exposes the result as
`salt_drift_*` metrics; Prometheus alerts `SaltDrift` / `SaltDriftCheckFailing` /
`SaltDriftCheckStale` / `SaltDriftCheckMissing`. On a `SaltDrift` alert: `salt '<minion>' state.apply test=True` shows
what differs — then either apply (git is right) or commit the change (the VM is right).
Force a check now: `salt '<minion>' schedule.run_job drift-check`.

## Inspect / debug

| Goal | Command |
|---|---|
| Render without applying | `salt '<minion>' state.show_sls <formula>` |
| Pillar a minion sees | `salt '<minion>' pillar.items` / `pillar.get <key>` |
| Verbose | append `-l debug` |
| Stale gitfs | `salt-run fileserver.update`, last resort `salt-run cache.clear_all` |

The `/salt-render-debug` skill walks through render/sync failures in order.

- **Pillar output is masked** on this master (`****`). To check a secret resolved without
  printing it, render the state as JSON and check the value's length / that it doesn't start
  with `sdb:` — e.g. `state.show_sls <formula> --out=json | python3 -c …`.
- A minion briefly "Not connected" usually means the VM rebooted — check `uptime` and
  `systemctl --failed` (the NFS mount especially) before anything else.

## Running non-trivial commands on minions

Nested quoting through `ssh` → `salt cmd.run` → `sh` breaks fast (Go templates in
`docker inspect -f`, JSON, `$` expansions). For anything beyond a one-liner, write a script
locally, `scp` it to the master, `salt-cp <minion> /tmp/x.sh /tmp/x.sh`, run it with
`cmd.run 'sh /tmp/x.sh'`, then delete it on both sides.

## Useful runtime facts

- Container data: `/opt/<formula>/…` on the minion (arrstack: `/opt/arrstack/<app>`).
- qBittorrent WebUI user `admin`. Forgotten password: stop container, remove
  `WebUI\Password_PBKDF2` from `/opt/arrstack/qbittorrent/qBittorrent/qBittorrent.conf`, start —
  a temporary password is printed to `docker logs qbittorrent`. "Bypass authentication for
  clients on localhost" must stay on (port-forwarding hook).
- gluetun logs the hook's `wget` success line as `ERROR [port forwarding] … URL:… [1]` — not an
  error. Real check: `docker exec gluetun wget -qO- http://127.0.0.1:8080/api/v2/app/preferences`
  → `listen_port` matches "port forwarded is …".
- Sonarr/Radarr/Prowlarr API keys: `<ApiKey>` in `/opt/arrstack/<app>/config.xml`;
  `GET /api/v3/health` (Prowlarr `v1`) shows their health warnings.
- After an arrstack restart Prowlarr may flag FlareSolverr as unavailable (it came up first);
  clears on its next health check or `POST /api/v1/indexerproxy/testall`.
