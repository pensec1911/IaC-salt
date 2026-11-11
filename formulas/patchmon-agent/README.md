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
- `patchmon-agent.config` — `/etc/patchmon` (0700); once enrolled: `credentials.yml` (0600,
  from OpenBao) and `config.yml`. The agent rewrites `config.yml` itself (interval,
  integrations, `host_id`), so Salt creates it once and afterwards only enforces
  `patchmon_server` and `ssh-proxy-enabled`/`rdp-proxy-enabled: false`.
- `patchmon-agent.service` — upstream's unit (`patchmon-agent serve`, `Restart=always`),
  restarted on a new binary, unit, credentials or server URL.

Not enrolled (no OpenBao entry for the minion): only the binary is installed, and a
`patchmon-agent-not-enrolled` state says so without failing.

## Enrol a minion (manual, once per minion)

Credentials are per host and shown only once, so this stays a UI step:

1. PatchMon → Hosts → **Add host**, friendly name = minion ID. Copy API ID and API key from the
   install command it shows — **don't run that command** (Salt installs the agent).
2. On the OpenBao host:
   ```sh
   read -rs KEY && printf %s "$KEY" | bao kv put -mount=homelab patchmon/agent/<minion> api_id=<API_ID> api_key=- ; unset KEY
   ```
3. Highstate the minion (or wait for its next enforce run). The host turns active in the UI
   after its first report.

Lost key: Host detail → Deploy Agent → API Credentials → Regenerate, then step 2 again.
Removing a minion: delete the host in the UI and `bao kv metadata delete -mount=homelab
patchmon/agent/<minion>`.

## Upgrades

With every server bump (Renovate PR for `ghcr.io/patchmon/patchmon-server`): set `version` and
`sha256` (from the release's `SHA256SUMS`, `patchmon-agent-linux-amd64`) in `map.jinja` in the
same change.

## Not managed

- Integrations (Docker inventory, compliance scans) — toggled per host in the UI; the agent
  writes them into `config.yml`.
- SSH/RDP proxy — always off (enforced).
