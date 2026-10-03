---
name: salt-secrets
description: Use whenever writing or editing pillar data that includes a credential, API key, password, token, or other secret value for a Salt-managed service. Ensures secrets are referenced via OpenBao (sdb://) instead of stored as plaintext in pillar files.
---

# Salt secrets via OpenBao

This repo never stores literal secret values in `pillar/*.sls` — see CLAUDE.md "Secrets in pillar".

When a pillar value is a credential:

1. Do not write the literal value into the pillar file.
2. Write it as an **explicit `sdb.get` call**, not a bare `sdb://` string:
   ```yaml
   some_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/<name>?<key>') | yaml_encode }}
   ```
   `<name>` is the KV-v2 sub-path under `homelab/data/` for that service, `<key>` the field name
   in that Vault entry. Both parts matter:
   - Salt does **not** auto-resolve a bare `sdb://` value in pillar — it reaches the state as the
     literal URI string, silently. Only `config.get` values and explicit `sdb.get` calls resolve.
   - `yaml_encode` quotes the resolved value, so a secret containing a quote, colon or leading `*`
     can't break the pillar YAML.
3. If the exact KV path/key for this service isn't known yet, ask rather than guessing — don't
   invent a plausible-looking path.
4. Remind the user, once and briefly, that the actual secret still needs to be written into
   OpenBao itself (e.g. `vault kv put` / `bao kv put`) — writing the `sdb://` reference in pillar
   does not create the secret.

Never suggest an environment variable, `.envrc`, or a hardcoded default in `map.jinja` as a
shortcut for a Salt-managed secret — those are exactly the patterns this convention avoids here.
(This is unrelated to OpenTofu's `.envrc` + `TF_VAR_` pattern, which is a separate, already-accepted
mechanism for a different tool.)
