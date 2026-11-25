{%- from 'features.jinja' import features %}
base:
  '*':
    - GLOBAL
{%- if features.wazuh %}
    - wazuh-agent
{%- endif %}
    - ntp
    - patchmon-agent
    - salt-minion-version
    - healthchecks-ping

  'homepage,monitoring,salt-master,forgejo,gateway,edge,cloud-edge':
    - match: list
    - salt-minion-enforce

  'arrstack,jellyfin':
    - match: list
    - salt-minion-enforce-window

  'arrstack,jellyfin,monitoring,wazuh,forgejo,gateway,cloud-edge':
    - match: list
    - backup

  'salt-master':
    - salt-master

  # salt-master_master: the master's own id, which the orchestrate run
  # (formulas/orch) compiles its pillar for.
  'salt-master,salt-master_master':
    - match: list
    - orch

  'homepage':
    - homepage

  'monitoring':
    - grafana
    - prometheus
    - alertmanager
    # Read by prometheus' blackbox job (probe targets = homepage items).
    - homepage
    - infra-exporters

  'arrstack':
    - nfs-mount
    - arrstack
    - seerr

  'wazuh':
    - wazuh

  'jellyfin':
    - jellyfin
    - ntfy
    - healthchecks

  'forgejo':
    - forgejo
    - netbox
    - patchmon
    - tofu-state

  'cloud-edge':
    - cloud-edge
    - headscale

  'gateway':
    - tailscale
