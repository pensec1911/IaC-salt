# salt-master formula

Manages the salt-master's own config so it pulls its state tree and pillar directly from this
repo (gitfs + git_pillar) instead of relying on a manually-copied `/srv/salt`. Generates its own
deploy key, pins GitHub's host key, and writes `/etc/salt/master.d/{gitfs,git_pillar,auto_accept}.conf`.

This is the one formula that isn't fully generic — `map.jinja`'s defaults point at this exact
repo (`pensec1911/IaC-salt`) since that's what a fresh master actually needs to bootstrap
against. Override via `salt-master:lookup` pillar (see `pillar.example.sls`) if the repo is ever
renamed or forked.

## Bootstrap

See the repo root `README.md` for the one-time manual step required before gitfs can take over
(the master has nothing to pull from until it's configured once).
