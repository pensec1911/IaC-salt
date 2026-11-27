# Secrets (OpenBao via sdb)

Secrets come from OpenBao, never plaintext in `git_pillar` — same idea as OpenTofu pulling creds
via AppRole. **Never write an actual secret value into any file in this repo.**

## Writing a secret reference in pillar

```yaml
api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/<service>?<key>') | yaml_encode }}
```

- **Explicit `sdb.get` call, never a bare `sdb://` string.** Salt does not resolve bare `sdb://`
  values in pillar (`salt/pillar/__init__.py` never calls `sdb_get`; only `config.get` and
  explicit `sdb.get` resolve). A bare reference reaches the state as the literal URI — silently,
  nothing in any log.
- **`yaml_encode` is mandatory** — quotes the value so a secret containing quotes, colons or a
  leading `*` can't break the pillar YAML.
- **Full KV-v2 API path, `data/` included**: `homelab/data/<service>`. The `vault` sdb driver has
  no path-prefix option. The `bao kv` CLI omits `data/` and adds it itself, so the same secret is
  `bao kv put -mount=homelab <service> key=value` on the CLI.
- Don't guess a KV path for a new service — ask. Writing the reference doesn't create the secret;
  the user puts it into OpenBao themselves.
- Don't use `ext_pillar vault` (pulls whole paths implicitly) or env vars / `map.jinja` defaults as
  shortcuts.

The `/salt-secrets` skill enforces this when editing pillar.

## Current KV layout (mount `homelab`, KV-v2)

| Path | Keys | Used by |
|---|---|---|
| `users/shared` | `password` (sha512-crypt hash, not plaintext) | `pillar/GLOBAL.sls` — every minion's self-named login. Shared on purpose; switch to per-minion by changing the path to `users/{{ grains['id'] }}`. |
| `gluetun/proton` | `private_key` | `pillar/arrstack.sls` (active VPN) |
| `gluetun/mullvad` | `private_key` | unused, kept as fallback |
| `slskd/credentials` | `soulseek_username`, `soulseek_password`, `web_username`, `web_password` | `pillar/arrstack.sls` |
| `grafana/admin` | `password` | `pillar/grafana.sls` |
| `wazuh/indexer-admin` | `password` | `pillar/wazuh.sls` — indexer `admin` (Filebeat, manager, dashboard login) |
| `wazuh/api` | `wui_password` | `pillar/wazuh.sls` — server API user `wazuh-wui` (dashboard → API) |
| `wazuh/registration` | `password` | `pillar/wazuh.sls` + `pillar/wazuh-agent.sls` — must be the same shared secret |
| `salt-api/alertmanager` | `token` | `pillar/salt-master.sls` + `pillar/alertmanager.sls` — bearer token for salt-api's `/hook/alertmanager`; must be the same on both sides |
| `forgejo/admin` | `username`, `password`, `token` | Not read by pillar — Forgejo's admin login (install wizard, formulas/forgejo README "First run") and a standing API token (scope `repository` RW only) for Claude sessions: PRs, branches, statuses via the API. Read it through the master (`salt-run salt.cmd sdb.get …`) straight into the request, never print it. |
| `forgejo/runner` | `secret` | `pillar/forgejo.sls` — 40-hex offline registration secret of the Actions runner, used on both sides (forgejo `runners`, forgejo-runner). Rotate: change the last 24 chars. |
| `salt-api/forgejo` | `hmac` | `pillar/salt-master.sls` — HMAC secret of the Forgejo push webhook to `/hook/git` (set on the webhook in `homelab/IaC-salt`); must be the same on both sides |
| `github/mirror` | `token` | Not read by pillar — fine-grained GitHub PAT (Contents RW on IaC-salt, IaC-opentofu) for Forgejo's push mirrors; stored encrypted in Forgejo's DB too. On rotation: update both. |
| `netbox/app` | `secret_key`, `db_password`, `api_token_pepper` | `pillar/netbox.sls` (formulas/netbox README "OpenBao") |
| `netbox/admin` | `username`, `password` | Not read by pillar — NetBox superuser (formulas/netbox README "First run") |
| `netbox/tofu` | `api_token` | Not read by pillar — v2 token of the NetBox user `opentofu`, read by `IaC-opentofu` (`vault.tf`) to write the inventory. The Tofu AppRole policy needs `read` on it. |
| `netbox/tofu-plan` | `api_token` | Not read by pillar — read-only (Write off) v2 token of `opentofu`, used by IaC-opentofu's plan/drift jobs in Forgejo Actions (AppRole `tofu-plan`). |
| `proxmox/plan` | `api_token` | Not read by pillar — token of `tofu-plan@pve` (PVEAuditor + VM.Config.Disk on `/`, Datastore.Allocate on `/storage/local` — a plan with refresh needs them; IaC-opentofu README "CI"), same jobs. |
| `proxmox/exporter` | `token_value` | `pillar/infra-exporters.sls` + `pillar/prometheus.sls` — UUID of the PVE API token `prometheus@pve!exporter` (PVEAuditor, privsep off; formulas/infra-exporters README). Exporter, scrape job and rules only exist while it resolves. |
| `fritzbox/exporter` | `password` | `pillar/infra-exporters.sls` + `pillar/prometheus.sls` — FRITZ!Box user `prometheus` (only "FRITZ!Box Einstellungen"), max. 32 chars. Exporter, scrape job and rules only exist while it resolves. |
| `tofu-state/postgres` | `password` | `pillar/tofu-state.sls` — DB user `tofu` of the Tofu state postgres; also in IaC-opentofu's local `backend.hcl` and the `PG_CONN_STR` Actions secret (formulas/tofu-state README). |
| `tofu-state/encryption` | `passphrase` | Not read by pillar — OpenTofu state encryption key (local `terraform.tfvars` + `STATE_PASSPHRASE` Actions secret). Lost = state unreadable; keep a copy outside the homelab. |
| `restic/cloud-edge` | `password` | `pillar/backup.sls` — restic repo password of cloud-edge only (OCI, outside the house; the others share `restic/repo`). Copy in the password manager. |
| `restic/salt-master` | `password` | `pillar/backup.sls` — restic repo password of salt-master only (its repo holds the master key; with `restic/repo` every minion could read it). Copy in the password manager — needed to restore a rebuilt master. |
| `headscale/gateway` | `auth_key` | `pillar/tailscale.sls` — single-use tagged Headscale pre-auth key for gateway's first login (formulas/headscale README "Manual steps"); stale after use, harmless. |
| `wireguard/cloud-edge`, `wireguard/gateway` | `private_key`, `public_key` | Not read by pillar — WireGuard tunnel keys, rendered into cloud-init by IaC-opentofu (AppRole `tofu`, never CI). |
| `oci/api`, `oci/plan` | `tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key`, `region`, `compartment_ocid` | Not read by pillar — OCI API keys of the users `opentofu` (apply) and `tofu-plan` (CI, read-only) for IaC-opentofu `oci/`. |
| `porkbun/api` | `api_key`, `secret_api_key` | Caddy's DNS-01 for `*.home.ilpaa.xyz` (step 5, formulas/caddy). |
| `authentik/app` | `secret_key`, `pg_password` | formulas/authentik on edge; its presence also turns on Caddy's forward auth (`pillar/caddy.sls`). |
| `authentik/oidc-grafana`, `-forgejo`, `-netbox` | `client_secret` | `pillar/authentik.sls` (provider secret, worker env) + the app's own pillar (`grafana`, `forgejo` oauth source, `netbox` extra_secrets) — same value on both sides. Write without trailing newline (`tr -d '\n'`). `authentik/oidc-seerr` exists but is unused (Seerr has no OIDC). |
| `ntfy/admin` | `password`, `password_hash` (bcrypt) | `pillar/ntfy.sls` reads only `password_hash` (ntfy `admin`, declaratively provisioned); `password` is the phone/web login (formulas/ntfy README "OpenBao") |
| `ntfy/healthchecks` | `password_hash` (bcrypt), `token` (`tk_…`) | `pillar/ntfy.sls` — ntfy user `healthchecks`, only declared while `token` resolves; the token is also entered in the Healthchecks ntfy integration (UI, formulas/healthchecks README) |
| `healthchecks/app` | `secret_key` | `pillar/healthchecks.sls` — Django `SECRET_KEY` |
| `healthchecks/project` | `ping_key`, `api_key` | Both created in the Healthchecks UI, both optional. `ping_key`: `pillar/healthchecks-ping.sls` (every minion), `pillar/alertmanager.sls` + `pillar/prometheus.sls` (Watchdog only while it resolves). `api_key` (read-write): `pillar/healthchecks.sls`, check provisioning |
| `ntfy/alertmanager` | `password_hash` (bcrypt), `token` (`tk_…`) | `pillar/ntfy.sls` (both) + `pillar/alertmanager.sls` (`token`, ntfy receivers only added while it resolves) — must be the same on both sides |
| `restic/repo` | `password` | `pillar/backup.sls` — restic repo password, shared by all minion repos. Changing it needs `restic key add` first (formulas/backup README); keep a copy outside the homelab. |

Check `grep -rn "sdb://" pillar/` for the authoritative list.

## How the master resolves them

- Vault support isn't in Salt core (3007) — it's the `saltext.vault` extension, installed into
  Salt's onedir Python via `salt-pip` by `formulas/salt-master/install.sls` (with `pygit2`).
  Missing it → `KeyError: 'vault.get'`.
- `formulas/salt-master/vault.sls` writes `/etc/salt/master.d/vault.conf`:
  - AppRole auth; `role_id` from pillar (`salt-master:lookup`, not secret).
  - `secret_id` must be the **literal credential**, not a file path — saltext.vault sends it
    verbatim (`invalid role or secret ID` otherwise). The template reads it at render time from
    `/etc/salt/vault-secret-id` on the master (manual, never in git).
  - The sdb profile `osvault: {driver: vault}` is a **top-level** key. Nested under `sdb:` it's
    never found and references resolve to the literal URI.
  - `server.verify` points at the OpenBao CA (self-signed cert).
  - File is `0640 root:salt`, not `0600` — the master daemon runs as `salt`, and an unreadable
    file in `master.d/` makes every `salt` command die with `PermissionError`.

## Bootstrap the AppRole

One-time manual step (policy, role, writing `secret_id` without trailing newline): see
[formulas/salt-master/README.md](../../formulas/salt-master/README.md#openbao-approle-manual-one-time).
Non-obvious policy paths: `sys/internal/ui/mounts/*` (KV version detection) and
`auth/token/create` (saltext.vault mints a child token per minion context, pillar rendering
included).

## Using the `bao` CLI on the OpenBao VM

The VM isn't a Salt minion and isn't reachable from Claude's sessions — the user runs `bao`
there as root. The cert is self-signed, so the CLI needs
`BAO_CACERT=/opt/openbao/tls/tls.crt` (+ `BAO_ADDR`), otherwise
`x509: certificate signed by unknown authority`. Both are exported in root's `.bashrc` there.
The web UI console can't do `secrets enable`/`policy write` — use the real CLI.
