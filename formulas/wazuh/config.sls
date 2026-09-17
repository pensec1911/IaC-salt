{% from "wazuh/map.jinja" import wazuh with context %}

include:
  - wazuh.install

{#- Deliberately NOT a full ossec.conf template — the package ships
   substantial default config (ruleset, decoders, active-response, etc.)
   that a wholesale overwrite would silently drop. Only the specific
   blocks pillar actually drives are patched in place. #}
wazuh-manager-indexer-block:
  file.blockreplace:
    - name: /var/ossec/etc/ossec.conf
    - marker_start: "<!-- SALT-MANAGED: indexer connection -->"
    - marker_end: "<!-- END SALT-MANAGED -->"
    - source: salt://wazuh/files/ossec-indexer-block.conf.j2
    - template: jinja
    - append_if_not_found: True
    - require:
      - pkg: wazuh-manager-package

wazuh-manager-auth-block:
  file.blockreplace:
    - name: /var/ossec/etc/ossec.conf
    - marker_start: "<!-- SALT-MANAGED: agent enrollment -->"
    - marker_end: "<!-- END SALT-MANAGED -->"
    - source: salt://wazuh/files/ossec-auth-block.conf.j2
    - template: jinja
    - append_if_not_found: True
    - require:
      - pkg: wazuh-manager-package
      # Both blockreplace states target the same file — explicit ordering
      # instead of relying on SLS declaration order.
      - file: wazuh-manager-indexer-block

wazuh-authd-password:
  file.managed:
    - name: /var/ossec/etc/authd.pass
    - contents: {{ wazuh.manager.registration_password | yaml_dquote }}
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: wazuh-manager-package

opensearch.yml:
  file.managed:
    - name: /etc/wazuh-indexer/opensearch.yml
    - source: salt://wazuh/files/opensearch.yml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: wazuh-indexer-package

opensearch_dashboards.yml:
  file.managed:
    - name: /etc/wazuh-dashboard/opensearch_dashboards.yml
    - source: salt://wazuh/files/opensearch_dashboards.yml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0640'
    - require:
      - pkg: wazuh-dashboard-package
