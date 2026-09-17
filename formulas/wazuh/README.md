# wazuh formula

Installs the full Wazuh stack — indexer (OpenSearch-based), manager, dashboard — from Wazuh's
official apt repo, native packages (not Docker — this repo's other services use Docker, but
Wazuh's own recommended production install method is native packages, and its official Docker
compose setup runs its own cert-generation container anyway, so native doesn't actually cost
anything here). Heavy on resources, especially the indexer's JVM heap — give this VM real memory,
not a minimal footprint like the other single-purpose VMs in this repo.

Pairs with `formulas/wazuh-agent`, which any other minion includes to get monitored by this one —
see that formula's README for how agent enrollment actually works.

## What it manages

- `wazuh.install` — apt repo + `wazuh-indexer`/`wazuh-manager`/`wazuh-dashboard` packages. The GPG
  key is ASCII-armored (unlike `docker`'s), so it's dearmored via `gpg --import` into a binary
  keyring rather than `file.managed` + `skip_verify` the way `formulas/docker` does it.
- `wazuh.config` — patches specific config blocks into the packages' own shipped config files
  (indexer connection + agent-enrollment settings into `ossec.conf`, the registration password
  into `authd.pass`) rather than replacing them wholesale, plus fully templates `opensearch.yml`
  and `opensearch_dashboards.yml` (small, self-contained files where a full template is safe).
- `wazuh.service` — starts indexer, then manager and dashboard (both depend on the indexer being
  up), restarting on config changes.

## What this formula deliberately does NOT do

**Generate TLS certificates or initialize the indexer's security plugin.** Indexer↔manager↔
dashboard communication is all mutual-TLS, and getting cert generation subtly wrong on a security
tool is worse than not automating it. This is treated as a manual, one-time bootstrap step — same
spirit as the gitfs deploy key or the OpenBao AppRole `secret_id` elsewhere in this repo — not
something `state.apply` does on every run anyway (certs shouldn't be regenerated idempotently).

### TLS bootstrap (manual, one-time)

Before `state.apply wazuh` will actually work:

1. Use Wazuh's own certificate generation tool (`wazuh-certs-tool.sh`, current version — check
   Wazuh's install docs for the exact download/invocation, this repo doesn't script it) to
   generate a CA plus per-component certs. Give the indexer node the same `node_name` you set (or
   left default, `wazuh-indexer-1`) in pillar, and give the admin cert the Subject DN you'll put in
   `wazuh:lookup:indexer:admin_dn`.
2. Place the resulting files on the `wazuh` minion:
   - `{{ indexer.certs_dir }}` (default `/etc/wazuh-indexer/certs`): `root-ca.pem`,
     `<node_name>.pem`, `<node_name>-key.pem`
   - `{{ manager.certs_dir }}` (default same as indexer's): `root-ca.pem`, `admin.pem`,
     `admin-key.pem` (the manager needs these to authenticate to the indexer's REST API)
   - `{{ dashboard.certs_dir }}` (default `/etc/wazuh-dashboard/certs`): `root-ca.pem`,
     `dashboard.pem`, `dashboard-key.pem`
3. Set `wazuh:lookup:indexer:admin_dn`/`node_dn` in pillar to match exactly what you generated —
   these go into `opensearch.yml`'s security config, and a mismatch means the indexer rejects
   connections outright.
4. Run the indexer's security initialization (loads the generated certs/admin identity into the
   security plugin) per Wazuh's current docs, before `state.apply` starts the manager/dashboard
   against it.

None of this is scripted here, unlike `bootstrap.sh` for the salt-master — the exact tool
invocation is too version-sensitive to hardcode with confidence.

## Usage

```yaml
# salt/top.sls
'wazuh':
  - users
  - wazuh
```

## Pillar

See `pillar.example.sls` for the full schema. Real values live in `pillar/wazuh.sls` (referenced
from `pillar/top.sls`).

`indexer:admin_password` and `manager:registration_password` are required in practice (no sane
default) and must be `sdb://` references, never literal values (CLAUDE.md "Secrets in pillar").
`registration_password` must be the exact same secret `formulas/wazuh-agent` uses — it's the
shared enrollment password every agent authenticates with against this manager's `authd`.

## Things worth double-checking before relying on this

Config file schemas here (`opensearch.yml`'s `plugins.security.*` keys, `opensearch_dashboards.yml`'s
`server.ssl.*`/`opensearch.*` keys, the exact `ossec.conf` `<indexer>`/`<auth>` block shape) are
based on general familiarity with Wazuh's architecture, not verified against current docs for
whatever version actually installs from the `4.x` apt repo at the time you run this — config keys
do shift between Wazuh releases. Check `salt 'wazuh' state.apply wazuh test=True` output and the
actual service logs (`journalctl -u wazuh-indexer`, `wazuh-manager`, `wazuh-dashboard`) rather than
assuming this is correct as written.
