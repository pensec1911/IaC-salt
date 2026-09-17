{% from "wazuh/map.jinja" import wazuh with context %}

wazuh-prereqs:
  pkg.installed:
    - pkgs:
      - curl
      - gnupg
      - apt-transport-https

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

wazuh-indexer-package:
  pkg.installed:
    - name: {{ wazuh.indexer.pkg }}
    - require:
      - pkgrepo: wazuh-repo

wazuh-manager-package:
  pkg.installed:
    - name: {{ wazuh.manager.pkg }}
    - require:
      - pkgrepo: wazuh-repo

wazuh-dashboard-package:
  pkg.installed:
    - name: {{ wazuh.dashboard.pkg }}
    - require:
      - pkgrepo: wazuh-repo
