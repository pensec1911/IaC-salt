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

### restic rest-server in append-only mode (ransomware-proof backups)

- **Why**: every minion writes its repo over NFS to `/mnt/backups/<minion>` with full rights —
  a compromised minion (or a bad `forget`) can delete its own backups along with the data. An
  append-only target means a client can only add snapshots; deleting needs a separate host.
- **Sketch**: `formulas/restic-server` (rest-server container, `--append-only
  --private-repos`, htpasswd user per minion with password via `sdb.get`) on a host that is not
  a backup client of itself, data dir on the NAS. `formulas/backup` switches
  `RESTIC_REPOSITORY` to `rest:https://…/<minion>/` per pillar; client-side `forget --prune`
  moves to one central prune job with a non-append-only credential. Metrics (`--prometheus`)
  into Prometheus. Restore test keeps working (reads are allowed).
- **Open**: which host (the NAS itself as an app would keep it off every minion); TLS for
  rest-server (ties into reverse proxy / internal CA); migrating existing repos (`restic copy`
  or just pointing at the same dir); where the prune credential lives so a minion can't get it.
  Combines well with the offsite copy above.

### Oxidized (config backup of network devices into Git)

- **Why**: OPNsense, FRITZ!Box and switches are managed by neither Tofu nor Salt — their config
  changes are invisible and unbacked. Oxidized pulls them on a schedule and commits each one to
  a Forgejo repo, so every change becomes a diff.
- **Sketch**: `formulas/oxidized` (container) on forgejo or monitoring; device list +
  per-model settings from pillar, read-only device credentials and a Forgejo deploy key via
  `sdb.get`; output to a private repo `network-configs` (git push). Status API → Prometheus
  (last successful pull per device). Homepage tile; backup only its config (the history lives
  in Git).
- **Open**: OPNsense model support (`opnsense` via SSH vs. the config.xml API); FRITZ!Box export
  includes secrets → the repo must stay private and tightly scoped; whether OPNsense's own
  git-backup plugin is the simpler path for that device.

### Healthchecks (dead-man's switch for jobs)

- **Why**: Prometheus only alerts on what it can scrape; if monitoring itself, Alertmanager or a
  timer silently stops, nothing fires. Healthchecks inverts it: every job pings after each run,
  a missing ping is the alert. Also the dead-man's switch for Alertmanager → ntfy (both on pve02).
- **Sketch**: `formulas/healthchecks` (container, SQLite → backup + `stop_containers`) on a host
  other than monitoring; checks per job from pillar (backup, restore test, salt-minion enforce,
  Renovate, Trivy, Tofu drift); job units get an `ExecStartPost`/`OnFailure` curl to the ping URL
  (URLs via `sdb.get`). Alertmanager's `Watchdog` alert pings a check too. Notifications to ntfy.
  Homepage tile.
- **Open**: provisioning checks as code (API or `manage.py` vs. clicking); if the healthchecks
  host dies, its own silence needs a second watcher (healthchecks.io free tier as last resort?).

### OpenBao PKI secrets engine (internal CA with short-lived certs)

- **Why**: OpenBao already runs and every secret goes through it — a PKI mount turns it into
  the internal CA without another service. Short-lived certs issued per host replace
  self-signed/plain-HTTP UIs and give salt-api, rest-server, Loki etc. real TLS.
- **Sketch**: offline-ish root (generated once, key kept out of OpenBao) → intermediate in a
  `pki_int` mount; one role per use (`homelab-servers`, short TTL); Salt issues and renews via
  the `vault` execution module or `sdb`/`http.query`, writes cert + key with `file.managed` and
  restarts the consumer on change. `CertificateExpiringSoon` already covers expiry. Also an option
  for the CA choice in the reverse-proxy entry.
- **Open**: root/intermediate creation and AppRole policy are security-critical bootstrap →
  manual, documented; OpenBao becomes a hard dependency for every renewal (and isn't backed up
  yet — known-issues "Backup gaps"); distributing the root to clients; ACME (OpenBao PKI speaks
  ACME) vs. Salt-driven issuance.

### OpenBao SSH secrets engine (short-lived SSH certificates)

- **Why**: logins today rest on static keys in `ssh_authorized_keys` (`formulas/users`) — a
  leaked key works until someone removes it from pillar on every host. Signed certificates with a
  TTL of hours expire on their own and carry the principal (user) in the cert.
- **Sketch**: `ssh-client-signer` mount in OpenBao with one role per principal set; `formulas/users`
  (or a small `ssh-ca` formula) drops the CA public key and sets `TrustedUserCAKeys` +
  `AuthorizedPrincipalsFile` via `file.blockreplace` in `sshd_config`; the client signs with
  `bao write ssh-client-signer/sign/<role>` before connecting. Optionally host certs too
  (`@cert-authority` in `known_hosts`, no more TOFU prompts on rebuilt VMs).
- **Open**: CA creation + roles/policies are security-critical bootstrap → manual, documented;
  break-glass if OpenBao is down (keep one static key per host, or only on the master?);
  shares the "OpenBao isn't backed up" gap with the PKI entry.

### CIS hardening + OpenSCAP compliance score

- **Why**: base hardening is implicit today (unattended-upgrades, users, Podman defaults) — there
  is no statement of *how* hardened a minion is, nor detection when it drifts. A benchmark turns
  that into a number per host.
- **Sketch**: `formulas/hardening` with the CIS Level 1 items that make sense for headless VMs
  (sysctl, sshd via `file.blockreplace`, mount options, auditd basics, disabled modules), each
  toggleable in pillar so exceptions are explicit and documented. Weekly `oscap xccdf eval`
  (SCAP Security Guide profile for the distro) via timer → score + failed-rule count as textfile
  metrics → Prometheus alert on drop; HTML report on the NAS.
- **Open**: which profile (CIS L1 server vs. ANSSI/STIG) and the distro's SSG coverage; rules
  that break Podman/NFS/Jellyfin (`noexec` on `/tmp`, IP forwarding, kernel modules) → per-minion
  exceptions; apply incrementally, `test=True` first per minion.

### Ephemeral test minion in CI (formulas tested on a real VM)

- **Why**: the pre-push hook and the render-check workflow only prove a minion *renders*. Whether
  a formula actually brings the service up (container starts, port answers, config valid) is only
  seen on the real minion after the push — which already deploys itself via `orch.push`.
- **Sketch**: a Forgejo workflow on PRs that touch `formulas/`: Tofu (`IaC-opentofu`, separate
  state/workspace) clones a throwaway VM from the template with a `ci-<run>` minion ID; master
  accepts it, a CI pillar (no real secrets — dummy values or a scoped OpenBao path) maps the
  changed formula(s); `state.apply` twice (second run must report 0 changes = idempotent); then
  goss/testinfra checks per formula (`formulas/<name>/tests/`); `tofu destroy` + key delete in an
  `always` step. Result as PR status.
- **Open**: runner needs Proxmox API + master access (scoped token, its own pool/VLAN); duration
  (clone + highstate ≈ minutes) → only changed formulas; NFS/VPN-dependent formulas need mocks or
  are skipped; leftover VMs/keys if the job dies (nightly sweeper).

### Packer golden images

- **Why**: `IaC-opentofu`'s `vm-template` downloads a stock cloud image; every new VM then installs
  salt-minion and runs its whole first highstate from scratch. A pre-baked image boots faster,
  is reproducible, and is the base the ephemeral test minion and the hardening entry want anyway.
- **Sketch**: Packer (`proxmox-iso` or `proxmox-clone` builder) in a Forgejo workflow, monthly +
  on change: stock cloud image → salt-minion (pinned version), `users`/`ntp`/`node-exporter`/
  `hardening` applied masterless (`salt-call --local` against this repo) → cloud-init reset →
  Proxmox template `debian-golden-<date>`. Tofu's template variable switches to it; Renovate
  bumps the base image checksum.
- **Open**: lives in `IaC-opentofu` or its own repo; masterless apply needs pillar without the
  sdb secrets (only secret-free formulas go into the image); template retention/rollback;
  keeping image and salt-minion version in sync with `formulas/salt-minion`.

### Chaos job (verify self-repair and alerting)

- **Why**: self-repair (hourly enforce, `orch.push`) and the alert rules are assumed to work but
  are only exercised when something really breaks. Breaking things on purpose, on a schedule,
  turns that into a tested property — the same idea as the weekly restore test for backups.
- **Sketch**: a scheduled Forgejo job (or timer on the master) picks one enforce-hourly minion
  and one fault from a pillar list — stop a container, edit a managed config file, stop
  node-exporter, disable a systemd unit; records the start time; then checks via Prometheus that
  the matching alert fired and via Salt that the next enforce run reverted it within the expected
  window. Result as metric (`chaos_last_success`, per fault) + alert when a repair or alert is
  missing.
- **Open**: only on hourly-enforce minions, never arrstack/jellyfin outside their window or
  forgejo during CI; a kill switch in pillar; faults must be safe (no data paths, no NFS, no
  network) — curated list, not random; runs on the ephemeral test minion first.

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
