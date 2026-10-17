include:
  - wazuh-agent.config

wazuh-agent-service:
  service.running:
    - name: wazuh-agent
    - enable: True
    - require:
      - file: wazuh-agent-client-block
      - file: wazuh-agent-authd-pass
    - watch:
      - file: wazuh-agent-client-block
      - file: wazuh-agent-authd-pass
