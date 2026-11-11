{% from "wazuh-agent/map.jinja" import wazuh_agent with context %}

wazuh-agent-prereqs:
  pkg.installed:
    - pkgs:
      - curl
      - gnupg
      - apt-transport-https

wazuh-agent-repo-key:
  cmd.run:
    - name: >-
        set -o pipefail &&
        curl -fsSL {{ wazuh_agent.apt_keyurl }} |
        gpg --no-default-keyring --keyring gnupg-ring:{{ wazuh_agent.keyring }} --import &&
        chmod 644 {{ wazuh_agent.keyring }}
    - shell: /bin/bash
    - unless: test -f {{ wazuh_agent.keyring }}
    - require:
      - pkg: wazuh-agent-prereqs

wazuh-agent-repo:
  pkgrepo.managed:
    - name: deb [signed-by={{ wazuh_agent.keyring }}] {{ wazuh_agent.apt_baseurl }} stable main
    - file: /etc/apt/sources.list.d/wazuh.list
    - require:
      - cmd: wazuh-agent-repo-key

wazuh-agent-package:
  pkg.installed:
    - name: wazuh-agent
    - require:
      - pkgrepo: wazuh-agent-repo
