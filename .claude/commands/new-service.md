---
description: Scaffold a new Salt formula following repo conventions
---

Create a new formula for the service: $ARGUMENTS

Follow CLAUDE.md exactly:
1. `formulas/<name>/map.jinja` — defaults dict, overlaid via `pillar.get('<name>:lookup', merge=True)`
2. `formulas/<name>/init.sls` — include list wiring install/config/service
3. `formulas/<name>/pillar.example.sls` — documents the pillar schema
4. `formulas/<name>/README.md`
5. If a dedicated system user is needed: append to `users:accounts` in `pillar/<name>.sls`,
   require it via `require: - user: user-<name>`, do NOT create the user locally
6. Add `pillar/<name>.sls` and reference it from `pillar/top.sls`
7. Ask me which minion this goes on before touching `salt/top.sls`

Reference `formulas/docker` or `formulas/homepage` for the established pattern. Don't guess at
values — ask if something isn't clear from an existing formula.