# Roadmap — next steps and future extensions

Ideas for extending the setup, not bugs (those go in [known-issues.md](known-issues.md)).
Each entry: why it fits *this* setup, a sketch, open questions. When an item ships, delete it
here (git history and the formula README carry it from then on); when one is rejected, move it
to "Deliberately not" with the reason so it isn't re-proposed.

Maintained by hand and by the `roadmap-curator` agent (`.claude/agents/`).

## Next up (agreed order)

Agreed 2026-11-27: Paperless first, Nextcloud second on the same VM.

### 1. Paperless-ngx (documents from the phone, OCR, auto-filing)

- **Why**: bills, contracts and subscription letters are scattered across mail, paper and
  phone. The only scanner is the phone; Paperless OCRs every upload, sets correspondent,
  document type and tags itself (matching rules first, its classifier after a few dozen
  documents) and files it via a storage path — the "it lands in the right folder" part that
  Nextcloud can't do (its Flow rules don't look at content).
- **Sketch**:
  - **VM** (IaC-opentofu, user's call): new `docs` VM on pve01, IP **192.168.178.21** (free in
    Tofu; check the FRITZ!Box before applying), 2–4 cores, sized **5–6 GB**
    from the start so Nextcloud (item 2) fits without a resize; pve01 then ~21 of 30 GB.
    Firewall: app port only from edge (.30) + monitoring (.25). New minion → `backup` in both
    top files, base formulas like the other container hosts (incl. `nfs-mount`, `podman`,
    `cadvisor`, `alloy`).
  - **NAS** (done 2026-11-27): dataset `/mnt/pool01/documents` with NFS share (host .21, no
    maproot/mapall) and child dataset `documents/paperless`. Child datasets are separate
    filesystems → without `crossmnt` the client sees `paperless/` empty through the parent
    share: mount the child via its own share (`/mnt/pool01/documents/paperless`, host .21) —
    verify on first mount. Owner **979:979** (`paperless` user in the `users` formula, next
    free 97x UID; container `USERMAP_UID/GID` = 979), mode 770, POSIX ACL type. Holds
    `media/` (originals + archive) and `consume/`. `require: - mount: nfs-mount-paperless`.
  - **Local disk**: Postgres, `data/` (search index, classifier), Redis — many small random
    writes, too slow / lock-unsafe on NFS (inventory: NAS ~1.3 MB/s random).
  - **`formulas/paperless`** via the podman macro: paperless-ngx, Postgres (shared with
    Nextcloud later — one DB per app), Redis. `PAPERLESS_CONSUMER_POLLING` (no inotify over
    NFS). No Gotenberg/Tika yet — only needed for mail bodies/Office files (see Later).
  - **Secrets** (OpenBao): Paperless secret key, DB password, admin password, OIDC client
    secret.
  - **Login**: route `docs` in `pillar/edge-routes.jinja` **without** forward auth — the
    mobile apps (Paperless Mobile / Swift Paperless) can't pass Authentik's forward-auth page.
    Web UI via Authentik OIDC (allauth), apps via Paperless account / API token. Reachable on
    LAN + tailnet only, like everything else.
  - **Homepage** item, **backup**: nightly Postgres dump (`dumps` feature of
    `formulas/backup`) + `data/` + config; `media/` is on the NAS (TrueNAS snapshots; the real
    gap is the parked offsite copy — matters more once tax/contract documents live here).
- **Manual (README)**: TrueNAS dataset/export; first admin user; Authentik OIDC provider;
  correspondents, document types, tags, matching rules; custom fields (`amount`, `due date`,
  `interval`); storage path e.g. `{{ document_type }}/{{ correspondent }}/{{ created_year }}/{{ title }}`;
  saved views ("Subscriptions", "Expenses <year>"); phone app login.
- **Open**: Paperless' own `document_exporter` as an extra backup format (easier restore than
  a DB dump + files); whether amounts get extracted automatically (see Later).

### 2. Nextcloud (files, calendar, contacts across phone profiles)

- **Why**: the phone uses several isolated Android user profiles — Android has no way to share
  files between them, so it has to go through a server every profile talks to. Nextcloud app
  in each profile = same files everywhere (offline folders, photo auto-upload); DAVx5 in each
  profile = same calendar and contacts; Notes app = same notes. Also general file sync/sharing
  for laptop and family.
- **Sketch**:
  - Same `docs` VM, `formulas/nextcloud` via the podman macro: nextcloud (fpm) + web server
    container + cron container; own database on the Paperless Postgres; Redis for file
    locking + cache. ~+2 GB RAM.
  - User data on the NAS: child dataset `documents/nextcloud` with its own share (not created
    yet — owner 33:33 for the image's `www-data` or a 97x UID remapped via Podman, decided at
    build time); DB, config, app
    data local. Previews/thumbnails are small writes → keep the preview cache local or limit
    preview generation.
  - **Login**: route `cloud` **without** forward auth (Nextcloud apps and DAVx5 can't pass it).
    Web UI via Authentik OIDC (`user_oidc`); apps/DAVx5 via per-profile **app passwords**
    (revocable one by one). Each phone profile needs its own Tailscale login against Headscale
    → each is an admin device in `pillar/headscale.sls` `admin_access`.
  - **Paperless link**: Nextcloud *External storage* — Paperless' `consume/` as a writable
    "Scan inbox" folder, Paperless' archive read-only (Nextcloud must never write into
    Paperless' `media/`). Optionally the `integration_paperless` app ("Send to Paperless"
    file action).
  - Secrets (admin password, DB password, OIDC client secret) in OpenBao, homepage item,
    backup: DB dump + `config/` + app data.
- **Manual (README)**: first install (`occ maintenance:install`), enabling apps (`user_oidc`,
  `files_external`, Notes, optionally `integration_paperless`), Authentik provider, External
  storage mounts, app passwords + DAVx5 per profile.
- **Open**: major upgrades must go one version at a time (`occ upgrade`) → Renovate PRs for
  Nextcloud are never merged blindly (and `integration_paperless` may lag a major release —
  disable it or wait); nginx vs. Caddy as the in-VM web server; whether photo auto-upload is
  wanted (NAS space, preview CPU).
- **Not solved by it**: clipboard between profiles. Cheapest option is the existing ntfy
  (`push` route): one topic as clipboard via the share sheet. KDE Connect only syncs phone ↔ PC.

## Later

No order agreed; pick as needed.

### Paperless mail import + amount extraction

- **Why**: subscriptions and invoices mostly arrive by mail. Paperless has a built-in IMAP
  fetcher with mail rules (sender/subject/body/attachment filters → tags, correspondent,
  document type, then mark read/move).
- **Sketch**: mail account + rules in the Paperless UI (or from pillar via its API);
  Gotenberg + Tika containers on `docs` (~+700 MB) to store whole mails as PDF. If the mailbox
  is at Proton: Proton Mail Bridge container (paid plan) for IMAP. IMAP/app password in
  OpenBao.
- **Open**: amounts into the `amount` custom field — by hand, a post-consume regex script,
  or an LLM add-on (paperless-gpt / paperless-ai: more RAM or an external API, and
  financial documents leaving the house); a monthly subscription total (saved view + API
  export to Grafana?).

### Blackbox probe from outside ("home is offline")

- **Why**: every probe runs on monitoring, inside the house. If the FRITZ!Box, the uplink or
  power is gone, nothing alerts — Alertmanager and ntfy are down too. cloud-edge (OCI) sits
  outside and already has a public IP.
- **Sketch**: a blackbox exporter + tiny Prometheus or a healthchecks-style cron on cloud-edge
  that checks the WireGuard handshake age / `hs.<domain>` reachability of the home side and
  pushes to an external notifier (ntfy.sh topic, e-mail) — not to anything at home.
- **Open**: which notifier works when home is down; avoid flapping on DSL reconnects.

### Local DNS for clients without Tailscale (AdGuard Home / Unbound)

- **Why**: the `*.home.ilpaa.xyz` names only resolve on Salt minions (`/etc/hosts`) and tailnet
  devices (MagicDNS). A TV, a guest laptop or a phone without Tailscale gets Porkbun's parking
  page. A LAN resolver with the route list as local records fixes that (plus ad blocking).
- **Sketch**: AdGuard Home (or Unbound) on edge or a small VM, records generated from
  `pillar/edge-routes.jinja`, FRITZ!Box hands it out via DHCP. Needs a firewall rule (53) and
  a capacity check.
- **Open**: what happens when it's down (FRITZ!Box as fallback resolver?).

### Headplane (web UI for Headscale)

- **Why**: nodes, keys and routes are managed via `podman exec headscale headscale …` on
  cloud-edge today. Optional comfort, not needed for one admin.
- **Open**: behind Caddy + Authentik (OIDC) on edge talking to Headscale's API through the
  tunnel, or on cloud-edge itself (public — no).

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

### Offsite copy of the restic repos — built, parked until the manual steps

- **Why**: `formulas/backup` writes every minion's repo to `/mnt/backups/<minion>` on the NAS
  only. NAS loss (or the house) takes the data and all its backups together — incl. Forgejo,
  salt-master's PKI and OpenBao's snapshot.
- **State (2026-11-27)**: built and committed, not pushed or applied, parked by the user.
  - IaC-opentofu branch `offsite-bucket`: private OCI bucket `homelab-restic`
    (`oci/offsite.tf`, `prevent_destroy`), output `restic_offsite_repository`.
  - IaC-salt branch `backup/offsite`: `formulas/backup-offsite` on salt-master — nightly 03:15
    `restic copy` of every repo on the share into its own offsite repo, forget 7d/4w/12m,
    check, per-repo metrics + alerts, Healthchecks check. Own offsite password.
- **To ship** (formula README "Bootstrap", IaC-opentofu README "Offsite-Bucket"):
  1. User: `tofu -chdir=oci apply` from `offsite-bucket`; OCI console: group + user
     `restic-offsite`, bucket-scoped policy, Customer Secret Key.
  2. User on OpenBao: `restic/offsite` (`password`, `access_key_id`, `secret_access_key`);
     offsite password (and the OpenBao unseal key) into the password manager.
  3. Then: replace `REPOSITORY_PLACEHOLDER` in `pillar/backup-offsite.sls` with the Tofu
     output, render check, merge both branches — not before step 2, or salt-master's state
     fails — first run by hand (`systemctl start restic-offsite.service`).
- **Later**: a read-back test of the offsite repos (`check --read-data-subset` / restore),
  today only the structure is checked.

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

- **Key acceptance via reactor** — keys are accepted by hand since `auto_accept` was turned off
  (formulas/salt-master README "Accepting minion keys"); security-critical bootstrap stays
  manual (CLAUDE.md hard rules), not reactor-driven.
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
