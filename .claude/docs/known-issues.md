# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## Backup gaps

- **OpenBao is not backed up**. OpenBao (.20, not a minion) holds every secret the pillar
  resolves, and nothing snapshots it. Options: a `bao operator raft snapshot save` timer to the
  NAS by hand on the host, or the salt-master pulling the snapshot over the API with a narrow
  AppRole policy into a path its own backup covers (salt-master README "Backup and restore").
  Security decision either way (CLAUDE.md: security-critical bootstrap stays manual).
  salt-master itself is backed up since 2026-11-27 (own repo password).

## Podman migration (2026-11-12) — follow-ups

- **Docker is still installed on the five container hosts** (stopped, disabled; old containers
  and images in `/var/lib/docker`, ~1.6–4 GB each) — the rollback path. Purge by hand once the
  hosts ran a while on Podman: formulas/podman README "Migration from Docker", step 3.
- **Hardening opt-outs** (map.jinja `podman` keys, reason in each comment): writable root for
  forgejo (deploy source — try read-only with a manual apply), gluetun, flaresolverr (Chromium
  profile), the LinuxServer images (s6 init) and both postgres; dind privileged in the host user
  namespace. Each is worth a try with a manual apply when there's time.
- **Downtime on a migration = image pull time**: `podman.migrate` stops Docker before the
  `<id>-image` pulls run. Irrelevant now that all hosts are migrated; matters for a new host only
  if it had Docker.
- **`salt-master:lookup:beacon_restart_services: [docker]`** is inert (no minion runs the
  service beacon). Dropping it rewrites the master's reactor config (master restart) — do it
  with a planned master apply.

## Zero-trust / edge — accepted risks and emergency access (2026-11-26)

- **Authentik is the single point of login** for every `auth: forward` route and the OIDC apps.
  Down → those names answer with errors. Emergency: the apps on their IP:port from a host the
  Proxmox firewall lets through (edge, monitoring — e.g. an SSH tunnel), local logins (Grafana
  `/login?disableAutoLogin=true`, NetBox form, Forgejo password), or switch a VM's firewall off
  in the Proxmox UI (VM → Firewall → Options). Lost passkey:
  `sudo podman exec -it authentik-worker ak create_recovery_key 10 <user>` on edge.
  akadmin = break-glass account, daily user `paul`.
- **App logins kept on purpose** (decided 2026-11-26): the *arr apps and qBittorrent still ask
  for their own password behind forward auth — a second layer if a VM firewall gets switched
  off. Not "External" auth.
- **Caddy → Proxmox/TrueNAS/OpenBao TLS isn't verified** (`tls_insecure`, self-signed certs).
  Pinning their CAs (pve-root-ca etc.) would close it.
- **Caddy cold start** (plan F13): its image is built on edge (formulas/caddy). Gone + build
  fails (no internet, Docker Hub down) → no proxy; apps still answer on their IPs from edge/
  monitoring.
- **WireGuard/Tailscale keys** (plan F9): the gateway snippet on the PVE host
  (`/var/lib/vz/snippets`), OCI instance metadata (IMDS, readable by any local process on
  cloud-edge) and the encrypted Tofu state hold the WG private keys.
- **cloud-edge can delete its own restic repo** on the NAS (rw NFS through the tunnel; own repo
  password, but the export is shared). Append-only rest-server (roadmap) would close it.
- **Seerr has no OIDC** (v3.5.2): own login (Jellyfin accounts), no forward auth (non-admin users).
- **NetBox Tofu provider 6.0 not merged**: a rewrite (renamed resources, state re-imports,
  NetBox 4.6 only — we run 4.7). Renovate PR stays open until a planned migration.
- **pve03 `local-lvm` at 92 %** (`PveStorageAlmostFull`, before step 7) — arrstack/forgejo disks.

## Smaller items

- **Old images filled forgejo's disk** (2026-11-26, 100 %; netbox/patchmon postgres PANICked
  and recovered). Fixed the same day: `podman-prune.timer` on every container host (weekly,
  keeps every image a Quadlet unit or container uses — formulas/podman), the runner's
  `forgejo-runner-dind-prune.timer` (daily), and `DiskFillingUp` (root fills within 24h at the
  6h trend). Watch forgejo's disk after busy CI days anyway (7.6 GB free on 2026-11-26).
- **NFS mounts missing after a cold start of the whole lab** (2026-11-26, after all servers were
  off): arrstack and jellyfin booted before TrueNAS served NFS; the mounts timed out
  (`nofail`/`_netdev`), the apps bound to them stayed stopped and nothing retried. The hourly
  drift check of self-repair minions would mount them; arrstack/jellyfin only repair in the
  night window. Fix by hand: `mount -a -t nfs4` + `state.apply`. Idea: an automount
  (`x-systemd.automount`) or a mount retry timer in `formulas/nfs-mount`.

- **Porkbun answers every unknown `*.ilpaa.xyz` name with its parking page** (wildcard record at
  Porkbun). A host without the `formulas/hosts` entries or MagicDNS resolves
  `<name>.home.ilpaa.xyz` there instead of to edge and fails TLS (seen in blackbox before its
  restart). Harmless, but confusing; delete the wildcard/parking record at Porkbun if it isn't
  used.

- **Healthchecks logs `Control server error: [Errno 30] Read-only file system: '/opt/healthchecks/'`**
  at every start (jellyfin, since 2026-11-15). gunicorn's control server wants to put a socket in
  the working dir, which the read-only root forbids. Harmless (workers, sendalerts, sendreports
  run), only noise. Fix: a tmpfs for that path in `formulas/healthchecks` (podman spec) or turn
  the control server off via gunicorn config/env — check which the v5 image supports.

- **TrueNAS sends no ZFS pool / disk temperature data yet** (2026-11-15): the Graphite exporter is
  set up and CPU/net/NFS/disk-I/O series arrive on monitoring :9108, but no `zfs_pool` /
  `disk_temperature`, so `TruenasPoolStateMissing` fires. Step 2 in
  `formulas/infra-exporters/README.md` (companion `netdata.conf` on TrueNAS) is still to do, and
  must be redone after every TrueNAS update.

- **pve03's onboard NIC hangs under load** (Intel I219-LM, `e1000e`: `Detected Hardware Unit
  Hang`, then link down; 4× on 2026-11-14, ~10k hang messages; pve01/02 have the same NIC
  and 0 hangs). The node goes red in Proxmox and arrstack/forgejo/omada drop off the network.
  Their NFS mounts block processes, which shows as load ~100 in the VMs. Replugging the cable
  brought it back. Mitigation, set by hand on pve03 (not managed by any repo yet):
  `post-up /usr/sbin/ethtool -K nic0 tso off gso off gro off` under `iface nic0` in
  `/etc/network/interfaces` (backup `interfaces.bak-2026-11-14`). If hangs continue
  (`journalctl -k | grep "Unit Hang"`), the next steps are a USB/PCIe NIC or
  `pcie_aspm=off`. The minions that hung after it: salt-minion reconnect watchdog.

- **bootstrap.sh still assumes GitHub** for the deploy key (registers it via `gh`). Since
  2026-10-26 the master pulls from Forgejo (`pillar/salt-master.sls` `gitfs_remote`), so on a
  rebuilt master the key goes to Forgejo `homelab/IaC-salt` → Settings → Deploy keys (read-only)
  instead. Forgejo must be up for a master rebuild; GitHub's mirror works as a fallback remote.

- **A salt-master restart triggers a highstate on every minion, arrstack/jellyfin included,
  at any hour** (seen 2026-10-26 12:48, when salt-api was introduced). On reconnect, the
  minions fire `salt/minion/<id>/start`, and the start reactor (`formulas/salt-master`)
  applies each one. This is older than salt-api and happens on every master restart, for
  example from a change to `master.d/*.conf` (manual apply, hourly enforce, or now
  `orch.push`). It is harmless while those hosts have no drift, but it bypasses the 03:00–06:00
  window. Possible fixes: the start reactor only applies if the minion itself just booted (an
  uptime check in an orchestrate step), or it runs the drift check instead of a highstate on
  minions that already have one.

- **A fresh VM from Tofu installs the newest 3008.\*, not the pinned Salt version.** The
  bootstrap pin (`IaC-opentofu` `modules/vm-instance`, `salt-pin-1001` = `3008.*`) only fixes
  the line. If the repo has a newer patch than `pillar/salt-minion-version.sls`, the new minion
  is newer than the master. `salt-minion.version` then fails (`…-newer-salt-common`, so
  `SaltDrift`) until it's downgraded by hand or the target is raised (master first,
  `orch.salt-upgrade`). Fix in the Tofu repo: set the module's pin variable to the exact
  target, or bump with Renovate in both repos.

- **apt-daily rarely refreshes the package lists** (seen 2026-10-26): `update-stamp` / lists on
  salt-master and homepage from 2026-10-18, wazuh and monitoring 2026-10-20; the journal shows
  `apt-daily.service` only right after boots, not the twice-daily runs (`OnCalendar=6,18:00`,
  `RandomizedDelaySec=12h`, `Persistent=true`). So u-u ran today against week-old lists.
  Cause not investigated (frequent reboots resetting the random delay? clock jumps?).
  `AptListsStale` (formulas/unattended-upgrades) will surface it; check
  `systemctl list-timers apt-daily.timer` over a few days before changing anything.

- **qBittorrent's WebUI freezes while it moves a finished torrent to the NAS** (2026-10-20,
  19:37–19:44, two South Park season packs): the move from local `incomplete_dir` to
  `/media/torrents` blocks qBittorrent 4.6's main loop — WebUI/API don't answer (LAN timeout,
  gluetun's PF hook `signal: killed`), log shows a gap and then "System wake-up event detected".
  Comes back by itself when the move is done; roughly minutes per tens of GB at the NAS's
  ~110 MB/s. Inherent to the local-disk-then-move design (arrstack README). Options if it
  bothers: accept it. Still the case on qBittorrent 5.3 (2026-11-15, one 6.7 GB movie): main
  thread in D state, WebUI timed out until the NFS writeback had drained, then back by itself.
  Check: `ps -eo pid,stat,comm | grep qbittorrent` (D) and `grep Writeback: /proc/meminfo`
  on arrstack.
- **Proton NAT-PMP renewals fail intermittently** (`recvfrom: connection refused` to
  `10.2.0.1:5351`, several times an hour on 2026-10-20). gluetun retries and gets the same port
  back within seconds, so qBittorrent keeps its listen port — noise, not an outage.
- arrstack majors (2026-11-14): Radarr 6, Prowlarr 2, qBittorrent 5 taken. Radarr 7 and
  Prowlarr 3 (.NET 10) are upstream pre-releases only (LSIO: develop/nightly tags) — take them
  once stable. Each major migrates its config/DB one-way: fresh backup first
  (`systemctl start restic-backup.service`, formulas/backup), read the release notes, then bump.

- **Tofu drift issue stays open: permanent diff on the three `debian13_template` VMs**
  (IaC-opentofu, seen 2026-11-14, already present before the move to `backend "pg"`). Every
  plan shows `ipv4_addresses` / `ipv6_addresses` / `network_interface_names`
  `[] -> (known after apply)`: computed fields of templates that never run. So the nightly
  `drift.yml` never sees an empty plan and its issue never closes. Fix in
  `modules/vm-template` (likely `lifecycle { ignore_changes }` or a provider setting), check with
  `tofu plan` → No changes.
