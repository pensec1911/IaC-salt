{%- from 'features.jinja' import features %}
base:
  '*':
    - GLOBAL
{%- if features.wazuh %}
    - wazuh-agent
{%- endif %}
    - ntp
    - patchmon-agent

  'homepage,monitoring,salt-master,forgejo':
    - match: list
    - salt-minion-enforce

  'arrstack,jellyfin':
    - match: list
    - salt-minion-enforce-window

  'arrstack,jellyfin,monitoring,wazuh,forgejo':
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

  'arrstack':
    - nfs-mount
    - arrstack
    - seerr

  'wazuh':
    - wazuh

  'jellyfin':
    - jellyfin

  'forgejo':
    - forgejo
    - netbox
    - patchmon
