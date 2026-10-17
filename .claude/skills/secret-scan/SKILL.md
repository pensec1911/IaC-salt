---
name: secret-scan
description: Use before committing/pushing, when asked whether anything sensitive is in the repo, or after writing to .claude/ (docs, skills, memory-like notes). Runs the repo's secret scanner and reviews for private data a regex can't catch.
---

# Secret / private-data scan

This repo is pushed to GitHub. Nothing may land there that's a credential or personal data.

## 1. Automated check

The pre-commit hook (`.githooks/pre-commit` → `.githooks/check-secrets.py`) runs on every commit
and blocks on findings. Make sure it's active and run it by hand:

```sh
git config core.hooksPath          # must print .githooks (SessionStart hook sets it)
python3 .githooks/check-secrets.py         # what's staged
python3 .githooks/check-secrets.py --all   # every tracked file
```

It catches: private keys, 32-byte base64 keys (WireGuard), crypt hashes, GitHub/OpenBao/AWS/API
tokens, credentials in URLs, `password:`/`token:`/`secret_id:`-style literals (incl. German
`Passwort`/`Kennwort`), e-mail addresses, public IPs, home-directory paths, and forbidden files
(`.env`, keys/certs, WireGuard configs, `vault-secret-id`, `.claude/settings.local.json`, `todo/`).

Never bypass with `git commit --no-verify`. For a verified false positive, append
`secret-scan: allow` to that line and say why in the commit message.

## 2. Manual review (what regex misses)

Read the staged diff (`git diff --cached`), with extra care for `.claude/` and `*.md`:

- Values pasted from a session: temporary passwords, API keys from container logs, VPN keys,
  OpenBao `secret_id`/`role_id` + token output — even in prose or code blocks.
- Personal data: real names, e-mail, phone, home address, account IDs, public IPs of the home
  connection or the VPN exit, GPS/location.
- Session-only notes that belong in local memory, not the repo (user preferences, feedback).
- Anything the user called private or sensitive.

Private LAN addresses (192.168.178.0/24), hostnames, ports, KV paths and `sdb://` references are
fine — they're documented on purpose (`.claude/docs/inventory.md`, `secrets.md`).

## 3. Report

List each finding as `file:line — what — suggested fix` (usually: move to OpenBao + `sdb.get`,
or drop it from the repo). If clean, say so in one line.
