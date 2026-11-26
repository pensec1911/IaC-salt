# hosts formula

Static name → IP entries in `/etc/hosts`, for names the LAN's DNS (FRITZ!Box) doesn't know.
Today: every `<name>.home.<domain>` route of `formulas/caddy` → `edge`, so that servers reach the
apps under the same name and certificate as browsers do (homepage status dots, blackbox probes,
OIDC back-channel calls from step 6 of the zero-trust plan). Podman containers inherit the host's
`/etc/hosts`.

## What it manages

One `host.present` per `hosts:lookup:entries` item (state ID `hosts-<ip>`). Adds missing names
and moves a name to the configured IP; other lines are left alone. A name removed from pillar
stays in the file until removed by hand.

## Pillar

`pillar/hosts.sls` builds `entries` from `pillar/edge-routes.jinja`. See `pillar.example.sls`.

## Not covered (manual)

Hosts Salt doesn't manage (Proxmox nodes, OpenBao, TrueNAS, your workstation) need the same
lines by hand if they should use the names, or reach them through the tailnet (MagicDNS records
from Headscale).
