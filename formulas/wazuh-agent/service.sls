include:
  - wazuh-agent.config

wazuh-agent-service:
  service.running:
    - name: wazuh-agent
    - enable: True
    - require:
      - file: wazuh-agent-client-block
    - watch:
      - file: wazuh-agent-client-block
