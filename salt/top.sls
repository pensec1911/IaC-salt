{#- pillar/features.jinja switches, exported by pillar/GLOBAL.sls. #}
{%- set wazuh = salt['pillar.get']('features:wazuh', False) %}
base:
  'salt-master':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - salt-master
    - orch

  'homepage':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - podman
    - cadvisor
    - alloy
    - homepage

  'monitoring':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - podman
    - cadvisor
    - blackbox-exporter
    - loki
    - alloy
    - grafana
    - prometheus
    - alertmanager
    - nfs-mount
    - backup

  'arrstack':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
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
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - wazuh
    - nfs-mount
    - backup

  'jellyfin':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - jellyfin
    - backup

  'forgejo':
    - users
    - ntp
{%- if wazuh %}
    - wazuh-agent
{%- endif %}
    - node-exporter
    - unattended-upgrades
    - patchmon-agent
    - salt-minion
    - nfs-mount
    - podman
    - cadvisor
    - alloy
    - forgejo
    - forgejo-runner
    - netbox
    - patchmon
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
