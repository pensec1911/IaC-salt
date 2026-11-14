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
  severity) on an existing container host; a user + access token in OpenBao. Set
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
- **To decide when it's built** — proxy and CA:
  - *Caddy*: proxy + built-in CA in one (`tls internal`, can also serve ACME to other hosts);
    simplest, config is one Caddyfile from pillar. Leaning this way.
  - *Traefik*: container-label routing, built-in forward-auth middleware; needs a CA/ACME source.
  - *nginx*: proxy only, no CA and no automatic certs — would need step-ca or OpenBao PKI.
  - CA: Caddy's internal CA / *step-ca* (separate ACME CA, also SSH certificates) /
    *OpenBao PKI* (already running, but makes OpenBao a dependency of every TLS renewal) /
    real domain + Let's Encrypt DNS-01 (no root to distribute, needs a public domain + DNS API).

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
  rate limits and deleted tags, and gives the Trivy workflow one local place to scan.
- **Sketch**: `formulas/zot` with `sync` extension in on-demand mode per upstream registry;
  storage on local disk (cache, rebuildable → no backup). a `registries.conf.d` mirror entry
  (formulas/podman) covers Docker Hub; other registries need the image prefix rewritten
  via a `registry` lookup key in the formulas.
- **Open**: rewriting image refs breaks Renovate's upstream lookup unless the original name
  stays in pillar and the prefix is added at render time; TLS for the registry (reverse proxy
  item or Zot's own cert); host choice (forgejo already has a container registry, but no
  pull-through).

### PatchMon (patch visibility per host)

- **Why**: unattended-upgrades patches Debian main/security daily, but the excluded repos
  (Salt, Wazuh — on purpose, `formulas/unattended-upgrades`) and non-minions (OpenBao,
  omada-controller, tailscale-router, Proxmox nodes) are invisible today. PatchMon shows
  pending updates per host in one place.
- **Sketch**: `formulas/patchmon` (server container + DB) on a container host; `formulas/
  patchmon-agent` on every minion, enrollment key via `sdb.get`. Non-minions enrolled by hand
  (documented in the README). Homepage tile + backup entry.
- **Open**: overlap with `RebootRequired` / a node_exporter textfile for pending updates
  (cheaper alternative: `apt-get -s upgrade` count → Prometheus alert); agent update path;
  whether it complements the Salt version-pin item (shows Salt drift across minions).

### OWASP Dependency-Track (SBOM + vulnerability history)

- **Why**: the Trivy workflow (`.forgejo/workflows/trivy.yml`) gives a weekly point-in-time
  scan. Dependency-Track keeps an SBOM per image and re-evaluates it as new CVEs appear, so
  "which running image is affected by CVE-X" is a query, not a re-scan.
- **Sketch**: `formulas/dependency-track` (API server + frontend + postgres, ~4 GB) on a container
  host; the Trivy workflow additionally emits CycloneDX SBOMs and uploads them per image
  (project = image, version = pinned tag). Notifications via webhook → ntfy. API key in
  OpenBao. Homepage tile + backup (postgres via the `dumps` feature of `formulas/backup`).
- **Open**: RAM (~4 GB; the wazuh VM is off, but essential services come first); whether old versions are
  deleted on a Renovate bump (keep only the deployed tag); does it make the Trivy issue
  report redundant.

### Greenbone / OpenVAS (network vulnerability scanning)

- **Why**: Trivy/Dependency-Track see image contents; nothing looks at the hosts from the
  network side (open ports, weak TLS, default creds, outdated services on non-minions like
  Proxmox, TrueNAS, FRITZ!Box, omada-controller).
- **Sketch**: Greenbone Community containers on a container host, scheduled weekly scan of the
  LAN range; scan target list from pillar (or later NetBox). Not always-on heavy if feeds +
  scanner are stopped between runs. Homepage tile + backup (gvmd postgres: targets, results).
- **Open**: RAM/CPU during scans (~4–8 GB); feed sync size; authenticated scans (SSH creds in
  OpenBao) or unauthenticated only; how results reach ntfy (GMP API script vs. mail).

### Nuclei (scheduled web-UI scanning)

- **Why**: cheap complement to Greenbone for the web UIs on homepage — misconfigurations,
  exposed admin panels, known CVEs in web apps — without a running service.
- **Sketch**: Forgejo Actions scheduled job: target list rendered from `pillar/homepage.sls`
  hrefs, `nuclei -severity medium,high,critical`, new findings → ntfy / Forgejo issue.
- **Open**: runner must reach the LAN (it does, it runs on forgejo); template pinning so
  results are reproducible; excluding intrusive templates (`-etags dos,fuzz`).

### CyberChef + IT-Tools (browser toolboxes)

- **Why**: decode/encode, hashes, JWT/cert inspection, regex, cron, subnet calc — locally
  instead of pasting secrets into random websites.
- **Sketch**: one `formulas/toolbox` with both static containers (stateless → no backup) on
  homepage or another light container host; two homepage tiles in a "Tools" group; behind SSO
  once that exists.
- **Open**: none worth noting — pick host and ports.

### Metrics for the non-minion infrastructure

- **Why**: Proxmox nodes, TrueNAS and the FRITZ!Box are only TLS/HTTP-probed
  (`pillar/prometheus.sls`) — no metrics for host RAM/CPU, ZFS pool health, disk SMART, WAN
  bandwidth or DSL sync. Exactly the hosts everything else depends on.
- **Sketch**: on monitoring: `prometheus-pve-exporter` (read-only PVE API token in OpenBao),
  a FRITZ!Box exporter (TR-064, read-only user), TrueNAS via its built-in Graphite/Netdata
  export or node_exporter-style app; alert rules for pool degraded, SMART failing, node RAM
  pressure (relevant for the RAM rebalancing). Grafana dashboards from the community.
- **Open**: TrueNAS SCALE version decides the export path; Scrutiny as the dedicated SMART UI
  vs. alerts only.

### gitleaks in Forgejo Actions (server-side secret scanning)

- **Why**: the pre-commit hook (`.githooks/`) only runs where `core.hooksPath` is set — not on
  commits from the Forgejo web editor, Renovate, or another clone. A CI check on every push/PR
  is the backstop, and it covers `IaC-opentofu` too.
- **Sketch**: workflow next to `.forgejo/workflows/render-check.yml`: `gitleaks git` on the
  pushed range (full history once), shared `.gitleaks.toml` with the repo's allowlist
  (`sdb.get` references, `pillar.example.sls` placeholders); failing check blocks PR merge.
- **Open**: reuse the patterns from the existing secret scanner or replace it with gitleaks
  locally too (one ruleset); what to do with a hit in history (rotate in OpenBao, no rewrite).

### OpenTofu plan in PRs + nightly drift check (IaC-opentofu)

- **Why**: Salt changes get a render check before merge; Tofu changes get nothing — `tofu plan`
  only runs on the user's machine. A plan as PR comment shows what a merge will create/destroy,
  and a nightly plan catches drift (VMs changed by hand in Proxmox).
- **Sketch**: Forgejo Actions workflow in `IaC-opentofu` on the existing runner: `tofu init`
  + `tofu plan -lock-timeout`, plan summary posted as PR comment; scheduled run → ntfy /
  Forgejo issue on non-empty plan. Proxmox API token (plan-only role where possible) and
  OpenBao access via Actions secrets. `apply` stays manual.
- **Open**: state is a local `terraform.tfstate` today → needs a remote backend first
  (Forgejo has no state backend; options: S3 on TrueNAS/Garage/MinIO, `pg` backend, or HTTP
  backend) plus state encryption (OpenTofu native); whether the runner may reach the Proxmox
  API; plan output may contain secrets → redact before posting. The plan also refreshes the
  `netbox_*` resources → needs the NetBox token (`netbox/tofu`, read-only would do for plan).

### Velociraptor (on-demand endpoint forensics)

- **Why**: Wazuh-style visibility (processes, persistence, logins, file hashes across all
  hosts) without an always-on 8 GB SIEM — query fleet-wide when something looks off (e.g. an
  OpenCanary/Greenbone/Nuclei finding), otherwise idle.
- **Sketch**: `formulas/velociraptor` (server, single binary, own datastore) on a container host or
  its own small VM; `formulas/velociraptor-client` on every minion with the client config
  rendered from pillar, deployment certs via `sdb.get`. Scheduled hunts for basics (new SUID
  files, new systemd units, new `authorized_keys`) → ntfy. Homepage tile + backup (datastore,
  server config — the CA key in it is security-critical).
- **Open**: server cert/CA generation is security-critical bootstrap → manual, documented;
  replaces or complements wazuh-agent (both is pointless once Wazuh goes); datastore growth.

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
- **NetBox as source of truth for Salt/Tofu** (ext_pillar, Tofu reading IPs from NetBox) —
  decided 2026-11-14: the direction is Tofu → NetBox only (`IaC-opentofu` `netbox.tf`, README
  "NetBox"). A `netbox` ext_pillar would make every render, the pre-push check and the hourly
  self-repair depend on a NetBox that runs on forgejo itself (circular with Git/CI), for
  pillar data that is almost all service config, not IPs. NetBox stays a read-only view.
