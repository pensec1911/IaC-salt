{% from "wazuh/map.jinja" import wazuh with context %}

include:
  - wazuh.certs
  - wazuh.indexer

{#- Merge only the keys Wazuh's guide edits into the package-shipped
   opensearch_dashboards.yml (cert paths there already match certs.sls).
   The kibanaserver credentials live in the dashboard's own keystore, set by
   wazuh-passwords-tool.sh during bootstrap — not in this file. #}
wazuh-dashboard-config:
  file.serialize:
    - name: /etc/wazuh-dashboard/opensearch_dashboards.yml
    - serializer: yaml
    - merge_if_exists: True
    - dataset:
        server.host: {{ wazuh.dashboard.server_host | yaml_dquote }}
        server.port: {{ wazuh.dashboard.server_port }}
        opensearch.hosts:
          - "https://{{ wazuh.node_ip }}:{{ wazuh.indexer_port }}"
        opensearch.ssl.verificationMode: certificate
    - user: wazuh-dashboard
    - group: wazuh-dashboard
    - mode: '0640'
    - show_changes: False   # first apply re-dumps the whole shipped file
    - require:
      - pkg: wazuh-dashboard-package
{%- if wazuh.bootstrapped %}

{#- Dashboard -> server API connection as wazuh-wui. Small self-contained
   file, so a full template is fine here. #}
wazuh-dashboard-api-config:
  file.managed:
    - name: /usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
    - source: salt://wazuh/files/wazuh.yml.j2
    - template: jinja
    - user: wazuh-dashboard
    - group: wazuh-dashboard
    - mode: '0600'
    - show_changes: False
    - makedirs: True
    - require:
      - pkg: wazuh-dashboard-package

wazuh-dashboard-service:
  service.running:
    - name: wazuh-dashboard
    - enable: True
    - require:
      - cmd: wazuh-dashboard-certs
      - service: wazuh-indexer-service
    - watch:
      - file: wazuh-dashboard-config
      - file: wazuh-dashboard-api-config
{%- endif %}
