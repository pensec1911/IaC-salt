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
