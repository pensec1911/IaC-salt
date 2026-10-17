{% from "wazuh/map.jinja" import wazuh with context %}

include:
  - wazuh.certs

{#- Patch the package's own blocks in ossec.conf, never append new ones:
   anything after </ossec_config> is rejected ("Invalid element"), and a
   second <indexer>/<auth> would leave the shipped placeholder one active
   too. The rest of the shipped config (rules, decoders, active response)
   stays untouched. #}
wazuh-manager-indexer-block:
  file.blockreplace:
    - name: /var/ossec/etc/ossec.conf
    - marker_start: '<indexer>'
    - marker_end: '</indexer>'
    - source: salt://wazuh/files/ossec-indexer-block.conf.j2
    - template: jinja
    - append_if_not_found: False
    - require:
      - pkg: wazuh-manager-package

{#- Agents enroll with the shared password (formulas/wazuh-agent). The
   shipped <auth> block is otherwise fine as is. #}
wazuh-manager-auth-use-password:
  file.replace:
    - name: /var/ossec/etc/ossec.conf
    - pattern: '<use_password>no</use_password>'
    - repl: '<use_password>yes</use_password>'
    - require:
      - file: wazuh-manager-indexer-block

wazuh-authd-password:
  file.managed:
    - name: /var/ossec/etc/authd.pass
    - contents: {{ wazuh.manager.registration_password | yaml_encode }}
    - user: root
    - group: wazuh
    - mode: '0640'
    - show_changes: False   # it's a secret — keep it out of state output / job cache
    - require:
      - pkg: wazuh-manager-package
{%- if wazuh.bootstrapped %}

{#- Indexer credentials for the manager (vulnerability detection etc.), via
   wazuh-keystore as in Wazuh's guide. Same change detector as
   filebeat.sls: hash written only after a successful update. #}
{%- set cred_hash = ('admin:' ~ wazuh.indexer.admin_password) | sha256 %}
wazuh-manager-keystore:
  cmd.run:
    - name: >-
        set -e;
        echo admin | /var/ossec/bin/wazuh-keystore -f indexer -k username;
        echo "$WAZUH_INDEXER_PW" | /var/ossec/bin/wazuh-keystore -f indexer -k password;
        (umask 077; printf %s "$CRED_HASH" > /var/ossec/etc/.salt-indexer-cred.sha256)
    - shell: /bin/bash
    - env:
      - WAZUH_INDEXER_PW: {{ wazuh.indexer.admin_password | yaml_dquote }}
      - CRED_HASH: {{ cred_hash }}
    - unless: test "$(cat /var/ossec/etc/.salt-indexer-cred.sha256 2>/dev/null)" = "{{ cred_hash }}"
    - hide_output: True
    - output_loglevel: quiet
    - require:
      - pkg: wazuh-manager-package
{%- endif %}

wazuh-manager-service:
  service.running:
    - name: wazuh-manager
    - enable: True
    - require:
      - cmd: wazuh-filebeat-certs
      - file: wazuh-authd-password
    - watch:
      - file: wazuh-manager-indexer-block
      - file: wazuh-manager-auth-use-password
      - file: wazuh-authd-password
      {%- if wazuh.bootstrapped %}
      - cmd: wazuh-manager-keystore
      {%- endif %}
