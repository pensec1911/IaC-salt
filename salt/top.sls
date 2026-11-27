{#- pillar/features.jinja switches, exported by pillar/GLOBAL.sls. #}
{%- set wazuh = salt['pillar.get']('features:wazuh', False) %}
base:
  'salt-master':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - salt-master
    - orch
    - openbao-snapshot
    - backup

  'homepage':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - podman
    - cadvisor
    - alloy
    - homepage

  'monitoring':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - podman
    - cadvisor
    - blackbox-exporter
    - loki
    - alloy
    - grafana
    - prometheus
    - alertmanager
    - toolbox
    - infra-exporters
    - nfs-mount
    - backup

  'arrstack':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - arrstack
    - seerr
    - backup

  'wazuh':
    - users
    - ntp
    - hosts
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - wazuh
    - nfs-mount
    - backup

  'jellyfin':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - jellyfin
    - ntfy
    - healthchecks
    - backup

  'forgejo':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - forgejo
    - forgejo-runner
    - netbox
    - patchmon
    - tofu-state
    - backup

  # Verwaltungstunnel zu cloud-edge (WireGuard + nftables aus Tofu-cloud-init),
  # spaeter Tailscale-Subnet-Router. Keine Container, wie salt-master.
  'gateway':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - tailscale
    - backup

  # Caddy + Authentik (Zero-Trust/SSO), Container-Host.
  'edge':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - caddy
    - authentik
    - backup

  # Paperless-ngx (later Nextcloud), documents on the NAS share.
  'docs':
    - users
    - ntp
    - hosts
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - paperless
    - backup

  # OCI A1 (arm64), Headscale. Erreicht das LAN nur durch den WireGuard-Tunnel
  # ueber gateway (Freigaben dort); Mine/Scrapes ueber wg0 (pillar/cloud-edge.sls).
  'cloud-edge':
    - users
    - ntp
    # No wazuh-agent: gateway doesn't forward 1514/1515 from the tunnel
    # (IaC-opentofu vms/gateway nftables; changing it means -replace).
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - healthchecks-ping
    - salt-minion
    - podman
    - cadvisor
    - alloy
    - nfs-mount
    - headscale
    - backup

  # Targeting is by minion ID, which matches the Tofu VM `name` in
  # IaC-opentofu/vms/<name>/main.tf (set as hostname via cloud-init).
  # Formula names below resolve into ../formulas/<name>/ (gitfs merges
  # formulas/ and salt/ into one flat namespace — see root README).
  # Add one entry per VM as its formula is built out, e.g.:
  # '<minion-id>':
  #   - users
  #   - wazuh-agent
  #   - node-exporter
  #   - <formula>
