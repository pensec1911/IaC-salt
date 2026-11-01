# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

_Nothing agreed yet — pick from "Later"._

## Later

No order agreed; pick as needed.

### Alertmanager receiver via self-hosted ntfy

- **Why**: `pillar/alertmanager.sls` is empty, so the "null" receiver applies. Alerts from
  `pillar/prometheus.sls` (BackupFailed, RestoreTestFailed, ProbeFailed, DiskAlmostFull,
  RebootRequired, …) and Wazuh are only visible if someone opens the UI or Grafana. ntfy is
  tiny (~50 MB) and gives phone push without a third-party account.
- **Sketch**: new `formulas/ntfy` (container, auth on, deny-all default, one topic per
  severity) on an existing Docker host; a user + access token in OpenBao. Set
  `alertmanager:config` in `pillar/alertmanager.sls` with a webhook receiver (ntfy speaks the
  Alertmanager format via `?template=alertmanager` or a small bridge), token via `sdb.get`;
  route by severity, group so a burst is one message. Homepage tile + backup entry (user DB).
- **Open**: which host (not monitoring itself — alerts must still arrive when it's down);
  dead-man's switch (Watchdog alert → external heartbeat, e.g. healthchecks.io) so a dead
  monitoring VM is noticed; phone access from outside (ntfy.sh upstream relay vs. the
  tailscale-router VM).

### Reverse proxy + local DNS (names and TLS instead of IP:port)

- **Why**: every UI is `http://192.168.178.x:port` — plain HTTP, credentials in clear text on
  the LAN, browser password managers confused by shared IPs. Names also make later moves
  (service to another VM) invisible to users and homepage.
- **Sketch**: `formulas/caddy` (or Traefik) on one host, routes from pillar
  (`name → upstream`), TLS from an internal CA (Caddy's `tls internal`, or a step-ca/OpenBao
  PKI intermediate). Local DNS via AdGuard Home (bonus: network-wide ad/tracker blocking) with
  a wildcard `*.home.<domain>` → proxy; FRITZ!Box hands it out as DNS server. Homepage
  `href`s and blackbox probes switch to the names; `CertificateExpiringSoon` covers the certs.
- **Open**: real domain + DNS-01 (Let's Encrypt, no CA to trust) vs. internal CA (root must be
  installed on every client — manual, documented); AdGuard as single point of failure for DNS
  (second instance or FRITZ!Box fallback); which services keep direct ports (Jellyfin TV apps,
  salt-api, Wazuh agents). Root CA key is security-critical bootstrap → stays manual.

### Single sign-on (OIDC, passkeys)

- **Why**: every UI has its own local login and password. One IdP with passkeys/2FA is the
  biggest security gain per GB of RAM: Grafana, Forgejo, Proxmox, OpenBao, Seerr and Jellyfin
  (SSO plugin) all speak OIDC; the rest (*arr, qBittorrent, Prometheus) can sit behind
  forward-auth on the reverse proxy.
- **Sketch**: Pocket ID (passkey-only, tiny) or Authelia (forward-auth + OIDC, config-as-code
  friendly) in its own formula; OIDC clients declared in pillar, client secrets in OpenBao
  via `sdb.get`. Needs the reverse proxy item first (OIDC wants stable HTTPS URLs).
- **Open**: Pocket ID vs. Authelia vs. Authentik (heaviest, most features); break-glass local
  admin per service stays; IdP down = locked out → backup + its own probe; OpenBao/Proxmox
  OIDC setup is security-critical → manual, documented.

### CVE scanning with Trivy in Forgejo Actions

- **Why**: Wazuh's vulnerability detector is the part of it that actually finds things, but
  it costs an 8 GB VM plus an agent everywhere. Trivy scans the pinned images
  (`formulas/*/map.jinja`) and the VMs' package lists for almost nothing, and fits the existing
  Forgejo runner + Renovate flow. Prerequisite for retiring the wazuh VM, if that happens.
- **Sketch**: scheduled Forgejo Actions workflow: extract image tags from `map.jinja`, `trivy
  image` each, report HIGH/CRITICAL with a fix available; optionally `trivy rootfs`/SBOM per
  minion via Salt. Results as a Forgejo issue (updated, not duplicated) or straight to ntfy.
- **Open**: noise filtering (`--ignore-unfixed`, severity floor); where the vuln DB cache lives
  on the runner; whether host-package CVEs are worth it given daily unattended-upgrades.

### NetBox as source of truth (IPAM/DCIM)

- **Why**: `inventory.md`, `pillar/*` and the Tofu `vms/*/main.tf` each hold IPs, ports and
  sizing by hand and drift apart. NetBox is a queryable inventory both IaC repos can read.
- **Sketch**: `formulas/netbox` (netbox + postgres + redis containers, ~2 GB) on a Docker host.
  Seed it with VMs, IPs and services from inventory.md. Later: Salt's built-in `netbox`
  ext_pillar for per-minion data, the Tofu `netbox` provider to register/look up VMs.
  Homepage tile + backup entry (postgres dump, not the live data dir).
- **Open**: which direction is authoritative (NetBox → Tofu/Salt, or Tofu writes, NetBox
  reads); whether inventory.md is then generated or dropped; API token in OpenBao; postgres
  backup = pre-backup `pg_dump` hook in `formulas/backup`.

### Zero-trust remote access (Headscale + Headplane, or alternative)

- **Why**: remote access currently goes through `tailscale-router` (Tofu VM) on Tailscale's
  cloud control plane. A self-hosted coordinator keeps keys, device list and ACLs at home
  and lets access be per-device/per-service instead of "on the LAN = trusted".
- **Sketch**: `formulas/headscale` with Headplane as web UI; ACL policy file from pillar;
  OIDC login via the SSO item; existing tailscale clients re-pointed with `--login-server`.
  Subnet router stays the `tailscale-router` VM. Homepage tile + backup (SQLite → `stop_containers`).
- **Open**: Headscale vs. NetBird (own control plane + relay, SSO-native) vs. Teleport
  (identity-aware SSH/web proxy with session recording); control server must be reachable
  from outside (FRITZ!Box port forward vs. small VPS) — network exposure is decided in the
  Tofu/OPNsense repos, not here; ACLs are firewall-like policy → keep them out of formulas, only
  as pillar data; DERP: own relay or Tailscale's public ones.

### Zot registry (pull-through cache for pinned images)

- **Why**: every image in `formulas/*/map.jinja` is pulled from Docker Hub/ghcr/lscr at
  apply time. Zot caches them on-demand, so applies and rebuilds survive upstream outages,
  rate limits and deleted tags, and gives Trivy one local place to scan.
- **Sketch**: `formulas/zot` with `sync` extension in on-demand mode per upstream registry;
  storage on local disk (cache, rebuildable → no backup). Docker daemon `registry-mirrors`
  (formulas/docker pillar) covers Docker Hub; other registries need the image prefix rewritten
  via a `registry` lookup key in the formulas.
- **Open**: rewriting image refs breaks Renovate's upstream lookup unless the original name
  stays in pillar and the prefix is added at render time; TLS for the registry (reverse proxy
  item or Zot's own cert); host choice (forgejo already has a container registry, but no
  pull-through).

### PatchMon (patch visibility per host)

- **Why**: unattended-upgrades patches Debian main/security daily, but the excluded repos
  (Docker, Salt, Wazuh — on purpose, `formulas/unattended-upgrades`) and non-minions (OpenBao,
  omada-controller, tailscale-router, Proxmox nodes) are invisible today. PatchMon shows
  pending updates per host in one place.
- **Sketch**: `formulas/patchmon` (server container + DB) on a Docker host; `formulas/
  patchmon-agent` on every minion, enrollment key via `sdb.get`. Non-minions enrolled by hand
  (documented in the README). Homepage tile + backup entry.
- **Open**: overlap with `RebootRequired` / a node_exporter textfile for pending updates
  (cheaper alternative: `apt-get -s upgrade` count → Prometheus alert); agent update path;
  whether it complements the Salt version-pin item (shows Salt drift across minions).

### Offsite copy of the restic repos

- **Why**: `formulas/backup` writes every minion's repo to `/mnt/backups/<minion>` on the NAS
  only. The weekly restore test proves the repos are good, but NAS loss (or the house) takes
  the data and all its backups together; that includes Forgejo, now the master's source of truth.
- **Sketch**: a timer on one minion (e.g. forgejo or monitoring, both mount the NAS) runs
  `restic copy` from each NAS repo to an S3/B2/Hetzner-style target, with credentials and the
  repo password via `sdb.get` from OpenBao. Pillar-driven in `formulas/backup`; weekly, after
  the restore test.
- **Open**: which provider; whether copying only forgejo, wazuh keys and the *arr/jellyfin
  configs (not media) is enough; how the offsite repo password is kept outside OpenBao itself
  (losing OpenBao loses the key to the copy). OpenBao isn't backed up at all yet
  (known-issues.md "Backup gaps") — fix that first, then its snapshot goes offsite too.

### Salt version upgrades via orch.rollout

- **Why**: salt-minion/salt-master come from the Salt repo, which unattended-upgrades excludes
  on purpose (`formulas/unattended-upgrades`), and the version isn't pinned anywhere. So Salt
  is either never upgraded or moves by accident with a manual `apt upgrade`, and minions can
  drift apart in version. The master must never be older than its minions.
- **Sketch**: pin the version in pillar (`salt-minion:lookup:version`, same for salt-master)
  with `pkg.installed: version=` plus an apt preference so a stray `apt upgrade` can't move it.
  A bump runs through `orch.rollout` in the right order: master first, then the minions
  one at a time with a `test.ping` / drift check after each restart. Renovate (already
  running for images) can propose the bump via a regex manager on the pillar pin. The
  onedir extras (pygit2 etc. via `salt-pip`, formulas/salt-master) must survive an upgrade
  — verify in the first rollout.
- **Open**: how a minion restarting its own salt-minion mid-state reports back (Salt's
  documented pattern is a delayed restart via `cmd.run` with `bg: True`); whether arrstack/
  jellyfin wait for their nightly window; how the restart interacts with the start reactor
  (known-issues.md: master restart → highstate everywhere).

## Deliberately not

- **Key acceptance via reactor** — keys are currently auto-accepted master-wide
  (`auto_accept: true`, see known-issues.md); if that changes, acceptance goes back to manual
  (security-critical bootstrap, CLAUDE.md hard rules), not to reactor-driven auto-accept.
- **diskusage beacon on the NFS mounts** — `DiskAlmostFull` (pillar/prometheus.sls) already
  covers them (`nfs4` isn't excluded), and there's nothing to heal automatically.
- **inotify beacon → re-apply on config change** — needs pyinotify in the onedir bundle, fires
  on Salt's own writes too (double highstate), and on arrstack/jellyfin it would be self-repair
  through the back door. The hourly enforce run covers the other minions.
