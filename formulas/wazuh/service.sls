include:
  - wazuh.config

{#- Indexer first — manager and dashboard both connect to it, and will
   fail their own startup checks if it isn't up yet. #}
wazuh-indexer-service:
  service.running:
    - name: wazuh-indexer
    - enable: True
    - require:
      - file: opensearch.yml
    - watch:
      - file: opensearch.yml

wazuh-manager-service:
  service.running:
    - name: wazuh-manager
    - enable: True
    - require:
      - service: wazuh-indexer-service
      - file: wazuh-manager-indexer-block
      - file: wazuh-manager-auth-block
      - file: wazuh-authd-password
    - watch:
      - file: wazuh-manager-indexer-block
      - file: wazuh-manager-auth-block
      - file: wazuh-authd-password

wazuh-dashboard-service:
  service.running:
    - name: wazuh-dashboard
    - enable: True
    - require:
      - service: wazuh-indexer-service
      - file: opensearch_dashboards.yml
    - watch:
      - file: opensearch_dashboards.yml
