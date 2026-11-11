# wazuh formula

Single-node (all-in-one) Wazuh 4.x server: **indexer**, **manager + Filebeat**, **dashboard** on
one minion, from Wazuh's apt repo. Built step by step after Wazuh's own
[step-by-step install guide](https://documentation.wazuh.com/current/installation-guide/index.html)
(4.14) — every command, path, file name and permission here comes from it. Native packages, not
Docker: that's Wazuh's recommended production install. Needs real memory (indexer JVM) — the VM
has 8 GB / 4 cores.

Pairs with `formulas/wazuh-agent` on every other minion.

## What Salt manages vs. what stays manual

| Salt (`state.apply`) | Manual, one-time (below) |
|---|---|
| Repo + packages, version-pinned and held (`wazuh:lookup:version`) | Generating certs (`wazuh-certs-tool.sh`) |
| Unpacking certs from the tar into each component's dir (names/modes/owners per guide) | Indexer security init (`indexer-security-init.sh`) |
| Patching only the guide's keys into the shipped `opensearch.yml` / `opensearch_dashboards.yml` (`file.serialize` merge) | Setting the indexer/API user passwords (`wazuh-passwords-tool.sh`) |
| Patching the shipped `<indexer>` block and `use_password` in `ossec.conf`; `authd.pass` | Putting those passwords into OpenBao |
| Filebeat config, alerts template, wazuh module | |
| *After bootstrap:* `wazuh-keystore` + Filebeat keystore (admin), dashboard `wazuh.yml` (wazuh-wui), Filebeat + dashboard services | |

Why the split: cert generation and the security plugin init are security-critical and one-time —
see `.claude/docs/patterns.md` "Security-critical bootstrap stays manual". The pillar flag
`wazuh:lookup:bootstrapped` keeps Salt away from everything that needs them until they're done.

Design notes:
- **Patch, don't replace.** The shipped configs carry paths, security defaults, rules and
  decoders. `ossec.conf` blocks are rewritten *inside* the existing `<indexer>` tags — appending a
  block after `</ossec_config>` makes the manager refuse to start, and a second `<indexer>` would
  keep the placeholder one.
- **No credentials in config files.** The manager and Filebeat read the indexer credentials from
  their keystores, the dashboard reads `kibanaserver` from its own keystore (set by the passwords
  tool). The only file with a password is `wazuh.yml` (0600), because that's where Wazuh reads it.
  Keystores can't be read back, so a root-only sha256 of the value is the change detector — the
  keystore command reruns only when the OpenBao value changes.
- **`node_ip` everywhere instead of localhost** — the certs are issued for the IP; Filebeat
  verifies the hostname.

## Bootstrap (one-time, in this order)

### 0. Secrets in OpenBao

Password policy (enforced by Wazuh): 8–64 chars, upper + lower case, digit, and one of `.*+?-`.

```sh
bao kv get -mount=homelab wazuh/indexer-admin            # exists — check it meets the policy
bao kv put -mount=homelab wazuh/api wui_password='<new>' # dashboard -> API user
```

Both must exist before any `state.apply` on `wazuh` — the pillar references them.

### 1. Generate the certs (on the wazuh VM, as root)

```sh
cd /root
curl -sO https://packages.wazuh.com/4.14/wazuh-certs-tool.sh
curl -sO https://packages.wazuh.com/4.14/config.yml
```

Edit `config.yml` to exactly one node per type — names must match pillar (`node_name`s; defaults
shown), IP = `node_ip`:

```yaml
nodes:
  indexer:
    - name: node-1
      ip: "192.168.178.27"
  server:
    - name: wazuh-1
      ip: "192.168.178.27"
  dashboard:
    - name: dashboard
      ip: "192.168.178.27"
```

```sh
bash ./wazuh-certs-tool.sh -A
tar -cvf ./wazuh-certificates.tar -C ./wazuh-certificates/ .   # if the tool didn't already
rm -rf ./wazuh-certificates
tar -tf wazuh-certificates.tar                                  # node-1*, wazuh-1*, dashboard*, admin*, root-ca*
tar -xOf wazuh-certificates.tar ./node-1.pem | openssl x509 -noout -subject
```

The subject must be `CN=node-1,OU=Wazuh,O=Wazuh,L=California,C=US` (the default `node_dn`). If
it isn't, set `wazuh:lookup:indexer:node_dn` in pillar to exactly what it prints. The tar stays
at `/root/wazuh-certificates.tar` (`certs_tar`) — never copy it into this repo.

### 2. First apply (`bootstrapped: false`)

```sh
salt wazuh state.apply test=True
salt wazuh state.apply
```

Installs everything, deploys the certs, starts **indexer** and **manager**. Filebeat and the
dashboard are installed but not started yet.

### 3. Initialize the indexer security plugin

```sh
/usr/share/wazuh-indexer/bin/indexer-security-init.sh
curl -k -u admin:admin https://192.168.178.27:9200              # cluster info, not an auth error
curl -k -u admin:admin https://192.168.178.27:9200/_cat/nodes?v
```

### 4. Set the passwords

```sh
curl -so wazuh-passwords-tool.sh https://packages.wazuh.com/4.14/wazuh-passwords-tool.sh
bash wazuh-passwords-tool.sh -u admin -p '<wazuh/indexer-admin from OpenBao>'
bash wazuh-passwords-tool.sh -u kibanaserver -p '<new kibanaserver password>'
```

On an all-in-one node the tool also updates the dashboard keystore. Then the server API users —
check `bash wazuh-passwords-tool.sh -h` for the exact `-A`/`-au`/`-ap` syntax of your version
before running it; the goal is `wazuh-wui`'s password = OpenBao `wazuh/api?wui_password`, and
ideally a new password for the `wazuh` API admin too (default credentials `wazuh`/`wazuh`,
`wazuh-wui`/`wazuh-wui`).

Store whatever isn't in OpenBao yet there (e.g. `wazuh/kibanaserver?password`,
`wazuh/api?wazuh_password`) — for the record, Salt doesn't read them.

### 5. Second apply (`bootstrapped: true`)

Set `bootstrapped: true` in `pillar/wazuh.sls`, push, then:

```sh
salt wazuh state.apply
```

Sets the manager/Filebeat keystores and `wazuh.yml`, starts Filebeat and the dashboard. Check:

```sh
filebeat test output                      # on the VM — all checks OK
systemctl is-active wazuh-indexer wazuh-manager filebeat wazuh-dashboard
```

Dashboard: `https://192.168.178.27` (self-signed), login `admin` / the indexer-admin password.
Agents (`formulas/wazuh-agent`) enroll on their own once port 1515 answers.

## Alerts to Alertmanager

`integration.sls` (only when `wazuh:lookup:alertmanager:url` is set): a custom integratord
integration `custom-alertmanager` (`/var/ossec/integrations/`, wrapper + `.py` run with Wazuh's
bundled Python) posts every manager alert with rule level >= 10 to Alertmanager's
`/api/v2/alerts`. The `<integration>` sits in its own `<ossec_config>` section appended to
`ossec.conf` between `SALT-MANAGED` comment markers (the shipped file has no such block to patch).

- `WazuhAlert` — labels `instance` (agent name, = minion ID; `wazuh` for the manager itself),
  `rule_id`, `wazuh_level`, `source=wazuh`; summary = rule description, description = log line.
- `WazuhVulnerability` — vulnerability-detector alerts, **Critical (level 13) only**: a full
  rescan emits one alert per CVE and agent (2026-10-18: 296 High + 51 Critical per agent, almost
  all `linux-image-amd64`, many "Package default status" guesses). Labels `cve`, `package`. The
  full CVE list stays in the dashboard (Vulnerability Detection).
- Events, not states: an alert resolves after 24 h (`resolve_after_hours`) unless it fires again
  with the same labels. Alertmanager has no receiver yet, so they show in its UI/Grafana only.
- Test without waiting for a real alert: `sudo /var/ossec/integrations/custom-alertmanager
  <alert.json> '' http://192.168.178.25:9093` (as user `wazuh`) with one line of `alerts.json`
  (level >= 10). To clear a test alert early, POST the same labels with `startsAt`/`endsAt`
  *in the past* — an `endsAt` still in the future is merged into the later one and changes
  nothing. Failures: `grep integratord /var/ossec/logs/ossec.log`.

## Usage

```yaml
# salt/top.sls
'wazuh':
  - users
  - wazuh
```

## Pillar

See `pillar.example.sls`. Real values in `pillar/wazuh.sls`. `indexer:admin_password`,
`manager:registration_password` and `dashboard:api_wui_password` are `sdb.get` references
(`.claude/docs/secrets.md`); `registration_password` is shared with `formulas/wazuh-agent`.

## Upgrading

Bump `wazuh:lookup:version` deliberately: the packages are held, and the Filebeat alerts template
is fetched from the matching git tag only once (`creates`) — delete
`/etc/filebeat/wazuh-template.json` to refetch it. Follow Wazuh's upgrade guide for the order
(indexer first).
