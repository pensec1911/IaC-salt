# patchmon-agent formula

The [PatchMon](https://patchmon.net) agent on every minion — reports packages, pending
(security) updates and reboot need to the server (`formulas/patchmon`, on forgejo). A static Go
binary as a systemd service, as root; no Docker needed, so it runs on salt-master too.
Read the server README's "Security model" first: the server can start patch runs on every
enrolled host.

## What it manages

- `patchmon-agent.install` — `/usr/local/bin/patchmon-agent` from the GitHub release, pinned
  by `version` + `sha256`. A binary changed by anything else (e.g. the server's auto-update,
  which stays off) is put back on the next highstate.
- `patchmon-agent.config` — `/etc/patchmon` (0700) and the enrol script
  (`/usr/local/sbin/patchmon-agent-enroll`). A minion without `credentials.yml` enrols itself
  (below) and keeps the credentials it gets back (0600, only the mode is enforced).
  `config.yml`: the agent rewrites it itself (interval, integrations, `host_id`), so Salt
  creates it once and afterwards only enforces `patchmon_server` and
  `ssh-proxy-enabled`/`rdp-proxy-enabled: false`.
- `patchmon-agent.service` — upstream's unit (`patchmon-agent serve`, `Restart=always`),
  restarted on a new binary, unit, enrolment or server URL.

No credentials and no token in OpenBao: only the binary is installed, and a
`patchmon-agent-not-enrolled` state says so without failing.

## Enrolment

Automatic, through PatchMon's auto-enrollment API. The token is the one manual step:

1. PatchMon → Settings → Integrations → **Auto-enrollment** → new token. Restrict it as far as
   the UI allows (allowed IP range = the homelab LAN, a small max hosts per day, a default host
   group if wanted). Copy key and secret — the secret is shown only once.
2. On the OpenBao host:
   ```sh
   read -rs S && printf %s "$S" | bao kv put -mount=homelab patchmon/enroll key=<TOKEN_KEY> secret=- ; unset S
   ```
3. Highstate (or wait for the enforce runs). Each minion without `/etc/patchmon/credentials.yml`
   posts its minion ID + `/etc/machine-id` to `/api/v1/auto-enrollment/enroll`, writes the
   returned `credentials.yml`, deletes the token file, and the service starts.

The per-host credentials exist only on the host (`/etc/patchmon`, not in OpenBao, not in the
backup — a lost one is re-enrolled, not restored). The token, in pillar of every minion, can
only create hosts (within its limits) — not read or change any. Revoke it in the UI when no new
minions are expected; existing agents keep working.

Re-enrol a host (key lost, host deleted in the UI): `rm /etc/patchmon/credentials.yml`,
highstate. A host this token created that never reported gets a new key for its existing
entry; one that did report is refused (`409 machine_id_match` in the state output) — delete it
in the UI first.
Removing a minion: delete the host in the UI.

## Hosts that aren't minions (manual, once per host)

OpenBao, omada-controller, tailscale-router, the Proxmox nodes — no Salt, so they use
PatchMon's own `direct-host` enrolment script with the same token. As root on the host (the
secret is read without echo, so it's not in shell history or the URL):

```sh
read -rs S; curl -s -H "X-Auto-Enrollment-Key: <TOKEN_KEY>" -H "X-Auto-Enrollment-Secret: $S" \
  "http://192.168.178.29:3001/api/v1/auto-enrollment/script?type=direct-host" \
  | FRIENDLY_NAME=<hostname> sh; unset S
```

The script installs the agent binary served by the PatchMon server (same version as the server),
writes `/etc/patchmon/config.yml` + `credentials.yml` and a systemd unit. Its config has the SSH
proxy off and no RDP proxy — but nothing re-enforces that there, and nothing bumps the agent
(server auto-update is off). Agent update by hand after a server bump: replace
`/usr/local/bin/patchmon-agent` with the release binary (URL + sha256 in `map.jinja`),
`systemctl restart patchmon-agent`. Don't re-run the enrol script for that — a host that has
reported is refused (409). Check that `ssh-proxy-enabled: false` is still in
`/etc/patchmon/config.yml` now and then.

The token must still be valid (and its IP range must include the host) when you run it.

## Upgrades

With every server bump (Renovate PR for `ghcr.io/patchmon/patchmon-server`): set `version` and
`sha256` (from the release's `SHA256SUMS`, `patchmon-agent-linux-amd64`) in `map.jinja` in the
same change.

## Not managed

- Integrations (Docker inventory, compliance scans) — toggled per host in the UI; the agent
  writes them into `config.yml`.
- SSH/RDP proxy — always off (enforced).
