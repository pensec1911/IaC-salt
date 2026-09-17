# wazuh-agent formula

Installs the Wazuh agent from the same official apt repo `formulas/wazuh` uses, and points it at
a manager for **auto-enrollment** — this is the direct answer to "can agents just be added to the
server and it starts collecting data": yes, that's what this formula sets up.

## How enrollment actually works

The manager runs `wazuh-authd`, listening on port 1515, gated by a shared registration password
(`/var/ossec/etc/authd.pass` on the manager, set from `formulas/wazuh`'s `manager:
registration_password`). An agent configured with that same password in its own `<enrollment>`
block connects to the manager on first start, authenticates with the password, and gets issued a
unique agent key automatically — no manual `manage_agents`/key-copying step. Once enrolled, it
starts shipping data to the manager on port 1514 (`<server><address>`) on its own. Nothing beyond
`state.apply`-ing this formula on a minion and having the shared secret match is needed to bring a
new minion under Wazuh's watch.

## What it manages

- `wazuh-agent.install` — same apt repo pattern as `formulas/wazuh` (dearmored GPG key,
  `wazuh-agent` package). Duplicated rather than shared with `formulas/wazuh` — they're separate
  formulas for a server and a client that never run on the same minion (the manager monitors
  itself via its own built-in local agent, it doesn't need this formula too).
- `wazuh-agent.config` — patches the `<client>` (manager address) and `<enrollment>` (manager
  address + registration password) blocks into the package's own default `ossec.conf`, same
  block-patch approach as `formulas/wazuh` (the shipped default already has sensible
  localfile/syscheck monitoring — no reason to replace it wholesale).
- `wazuh-agent.service` — runs `wazuh-agent`, restarting on config changes.

## Usage

Add to any minion that should report to the Wazuh manager — every minion in this repo except
`wazuh` itself gets this (see `pillar/wazuh-agent.sls`):

```yaml
# salt/top.sls
'some-minion':
  - users
  - wazuh-agent
  - some-service
```

## Pillar

See `pillar.example.sls` for the full schema. Since the same manager address + registration
secret applies to every monitored minion, this is the one formula meant to be referenced from
`'*'` in `pillar/top.sls` (alongside `GLOBAL`) rather than per-minion.

Both `manager_address` and `registration_password` are required in practice (no sane default —
see `map.jinja`). `registration_password` must be an `sdb://` reference (CLAUDE.md "Secrets in
pillar") and must be the exact same secret as `formulas/wazuh`'s `manager:registration_password`
— it's a shared secret between the two formulas, not per-formula data.
