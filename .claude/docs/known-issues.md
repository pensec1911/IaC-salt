# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## Security

- **`auto_accept: true` on the master** (`formulas/salt-master/files/auto_accept.conf`, "closed
  homelab LAN"). Any LAN host running salt-minion gets its key accepted and is served the `'*'`
  pillar — that includes the shared login password hash from `pillar/GLOBAL.sls` and the
  wazuh-agent pillar. Options: turn it off and accept keys by hand (`salt-key -a`) after each
  Tofu provision, or `autosign_grains` / pre-seeded keys from Tofu. The start reactor
  (formulas/salt-master) does not widen this — an accepted minion can already pull its own
  highstate/pillar.

## Backup gaps

- **salt-master and OpenBao are not backed up** (`pillar/backup.sls` covers arrstack, forgejo,
  jellyfin, monitoring, wazuh only). salt-master holds state Salt can't rebuild:
  `/etc/salt/pki/master` (a new master key makes every minion refuse the master — they cache
  its pubkey — so each needs `minion_master.pub` removed by hand) and the salt-api cert under
  `/etc/salt/pki/api`. OpenBao (.20, not a minion) holds every secret the pillar resolves, and
  nothing snapshots it. Options: salt-master gets `backup` in both top files plus its pki paths
  (needs the NAS export allowed for .28 and `nfs-mount`); for OpenBao a `bao operator raft
  snapshot save` timer to the NAS — either by hand on the host or by making it a minion, which
  is a security decision (CLAUDE.md: security-critical bootstrap stays manual).

## Podman migration (2026-11-12) — follow-ups

- **Docker is still installed on the five container hosts** (stopped, disabled; old containers
  and images in `/var/lib/docker`, ~1.6–4 GB each) — the rollback path. Purge by hand once the
  hosts ran a while on Podman: formulas/podman README "Migration from Docker", step 3.
- **Hardening opt-outs** (map.jinja `podman` keys, reason in each comment): writable root for
  forgejo (deploy source — try read-only with a manual apply), gluetun, flaresolverr (Chromium
  profile), the LinuxServer images (s6 init) and both postgres; dind privileged in the host user
  namespace. Each is worth a try with a manual apply when there's time.
- **No image pruning**: tag bumps leave old images in `/var/lib/containers`. `podman image
  prune -a` by hand, or a timer in formulas/podman.
- **Downtime on a migration = image pull time**: `podman.migrate` stops Docker before the
  `<id>-image` pulls run. Irrelevant now that all hosts are migrated; matters for a new host only
  if it had Docker.
- **`salt-master:lookup:beacon_restart_services: [docker]`** is inert (no minion runs the
  service beacon). Dropping it rewrites the master's reactor config (master restart) — do it
  with a planned master apply.

## Smaller items

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
  bothers: qBittorrent 5 (see major bumps below — unverified whether it moves off the main
  thread), or accept it.
- **Proton NAT-PMP renewals fail intermittently** (`recvfrom: connection refused` to
  `10.2.0.1:5351`, several times an hour on 2026-10-20). gluetun retries and gets the same port
  back within seconds, so qBittorrent keeps its listen port — noise, not an outage.
- arrstack is on the latest release *within* each major (2026-10-17). Newer majors exist and
  were deliberately not taken: Radarr 6, Prowlarr 2, qBittorrent 5 — each migrates its config/DB
  one-way, so run a fresh backup first (`systemctl start restic-backup.service`, formulas/backup)
  and read the release notes before bumping.

- **Tofu drift issue stays open: permanent diff on the three `debian13_template` VMs**
  (IaC-opentofu, seen 2026-11-14, already present before the move to `backend "pg"`). Every
  plan shows `ipv4_addresses` / `ipv6_addresses` / `network_interface_names`
  `[] -> (known after apply)`: computed fields of templates that never run. So the nightly
  `drift.yml` never sees an empty plan and its issue never closes. Fix in
  `modules/vm-template` (likely `lifecycle { ignore_changes }` or a provider setting), check with
  `tofu plan` → No changes.
