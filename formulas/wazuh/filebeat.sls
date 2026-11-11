{% from "wazuh/map.jinja" import wazuh with context %}

include:
  - wazuh.certs
  - wazuh.indexer

{#- Filebeat ships the manager's alerts to the indexer — without it the
   dashboard stays empty. Steps and URLs straight from Wazuh's step-by-step
   server guide; downloads are one-time (`creates`). #}
wazuh-filebeat-config:
  cmd.run:
    # Marker in the same command: the package ships its own filebeat.yml, so
    # the file existing says nothing — and a re-download would undo the
    # hosts patch below.
    - name: >-
        curl -fsSo /etc/filebeat/filebeat.yml {{ wazuh.filebeat.config_url }}
        && touch /etc/filebeat/filebeat.yml.wazuh
    - creates: /etc/filebeat/filebeat.yml.wazuh
    - require:
      - pkg: filebeat-package

{#- The template points at 127.0.0.1, which isn't in the indexer's cert. #}
wazuh-filebeat-hosts:
  file.replace:
    - name: /etc/filebeat/filebeat.yml
    - pattern: 'hosts: \[.*\]'
    - repl: 'hosts: ["{{ wazuh.node_ip }}:{{ wazuh.indexer_port }}"]'
    - require:
      - cmd: wazuh-filebeat-config

wazuh-filebeat-template:
  cmd.run:
    - name: >-
        curl -fsSo /etc/filebeat/wazuh-template.json
        {{ wazuh.filebeat.template_url | replace('{version}', wazuh.version) }}
        && chmod go+r /etc/filebeat/wazuh-template.json
    - creates: /etc/filebeat/wazuh-template.json
    - require:
      - pkg: filebeat-package

wazuh-filebeat-module:
  cmd.run:
    - name: >-
        set -o pipefail &&
        curl -fsS {{ wazuh.filebeat.module_url }} | tar -xvz -C /usr/share/filebeat/module
    - shell: /bin/bash
    - creates: /usr/share/filebeat/module/wazuh
    - require:
      - pkg: filebeat-package
{%- if wazuh.bootstrapped %}

{#- Filebeat authenticates to the indexer as admin (Wazuh's default user
   mapping). The keystore can't be read back, so a root-only hash of the
   value written AFTER a successful update is the change detector — a failed
   update is retried on the next run. Values via env, never argv. #}
{%- set cred_hash = ('admin:' ~ wazuh.indexer.admin_password) | sha256 %}
wazuh-filebeat-keystore:
  cmd.run:
    - name: >-
        set -e;
        test -f /var/lib/filebeat/filebeat.keystore || filebeat keystore create;
        echo admin | filebeat keystore add username --stdin --force;
        echo "$WAZUH_INDEXER_PW" | filebeat keystore add password --stdin --force;
        (umask 077; printf %s "$CRED_HASH" > /etc/filebeat/.salt-indexer-cred.sha256)
    - shell: /bin/bash
    - env:
      - WAZUH_INDEXER_PW: {{ wazuh.indexer.admin_password | yaml_dquote }}
      - CRED_HASH: {{ cred_hash }}
    - unless: test "$(cat /etc/filebeat/.salt-indexer-cred.sha256 2>/dev/null)" = "{{ cred_hash }}"
    - hide_output: True
    - output_loglevel: quiet
    - require:
      - pkg: filebeat-package

wazuh-filebeat-service:
  service.running:
    - name: filebeat
    - enable: True
    - require:
      - cmd: wazuh-filebeat-certs
      - cmd: wazuh-filebeat-template
      - cmd: wazuh-filebeat-module
      - service: wazuh-indexer-service
    - watch:
      - file: wazuh-filebeat-hosts
      - cmd: wazuh-filebeat-keystore
{%- endif %}
