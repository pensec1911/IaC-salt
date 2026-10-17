{% from "wazuh/map.jinja" import wazuh with context %}
{#- Fail at render time instead of writing a broken config / empty secret. #}
{%- for key, val in [('node_ip', wazuh.node_ip), ('indexer:admin_password', wazuh.indexer.admin_password),
                     ('manager:registration_password', wazuh.manager.registration_password),
                     ('dashboard:api_wui_password', wazuh.dashboard.api_wui_password)] %}
{%- if not val %}{{ raise('wazuh:lookup:' ~ key ~ ' is required (pillar/wazuh.sls)') }}{% endif %}
{%- endfor %}

wazuh-prereqs:
  pkg.installed:
    - pkgs:
      - curl
      - gnupg
      - apt-transport-https
      - debconf
      - adduser
      - procps
      - tar

{#- Wazuh's GPG key is ASCII-armored, unlike docker's raw binary key (see
   formulas/docker/install.sls) — needs dearmoring via gpg --import into a
   binary keyring before apt can use it with signed-by=. #}
wazuh-repo-key:
  cmd.run:
    - name: >-
        set -o pipefail &&
        curl -fsSL {{ wazuh.apt_keyurl }} |
        gpg --no-default-keyring --keyring gnupg-ring:{{ wazuh.keyring }} --import &&
        chmod 644 {{ wazuh.keyring }}
    - shell: /bin/bash
    - unless: test -f {{ wazuh.keyring }}
    - require:
      - pkg: wazuh-prereqs

wazuh-repo:
  pkgrepo.managed:
    - name: deb [signed-by={{ wazuh.keyring }}] {{ wazuh.apt_baseurl }} stable main
    - file: /etc/apt/sources.list.d/wazuh.list
    - require:
      - cmd: wazuh-repo-key

{#- Pinned together: the Filebeat alerts template (filebeat.sls) is fetched
   from the git tag matching this version. #}
{%- for pkg in ['wazuh-indexer', 'wazuh-manager', 'wazuh-dashboard'] %}

{{ pkg }}-package:
  pkg.installed:
    - name: {{ pkg }}
    - version: {{ wazuh.version }}-1
    - hold: True
    - update_holds: True   # so bumping wazuh:lookup:version can move a held package
    - require:
      - pkgrepo: wazuh-repo
{%- endfor %}

{#- Filebeat comes from the same Wazuh repo (OSS build Wazuh supports). #}
filebeat-package:
  pkg.installed:
    - name: filebeat
    - hold: True           # keep apt upgrade from moving it off the Wazuh-supported build
    - require:
      - pkgrepo: wazuh-repo
