{%- from 'features.jinja' import features %}
base:
  '*':
    - GLOBAL
{%- if features.wazuh %}
    - wazuh-agent
{%- endif %}
    - ntp
    - patchmon-agent

  # Docker -> Podman migration (2026-11): the container hosts are out of
  # self-repair until each one is migrated by hand (/deploy), so a push
  # doesn't roll the migration out on its own. Back to
  # 'homepage,monitoring,salt-master,forgejo' / 'arrstack,jellyfin' after.
  'salt-master':
    - salt-minion-enforce

  'homepage,monitoring,arrstack,jellyfin,forgejo':
    - match: list
    - salt-minion-beacons

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
