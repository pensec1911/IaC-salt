{% from "wazuh-agent/map.jinja" import wazuh_agent with context %}

include:
  - wazuh-agent.install

{#- Migration: earlier versions appended a marker block AFTER the closing
   </ossec_config>, which wazuh-agentd rejects ("Invalid element 'client'").
   Removes it; a no-op once gone. Drop this state once every agent minion has
   been applied. #}
wazuh-agent-remove-legacy-block:
  file.replace:
    - name: {{ wazuh_agent.ossec_conf }}
    - pattern: '\n?<!-- SALT-MANAGED: server \+ enrollment -->.*?<!-- END SALT-MANAGED -->\n?'
    - repl: ''
    - flags: ['DOTALL']
    - bufsize: file
    - require:
      - pkg: wazuh-agent-package

{#- Wazuh reads the enrollment password only from this file, never inline in
   ossec.conf. Same ownership/mode the package uses for its other secrets
   (client.keys). #}
wazuh-agent-authd-pass:
  file.managed:
    - name: {{ wazuh_agent.authd_pass_file }}
    - contents: {{ wazuh_agent.registration_password | yaml_encode }}
    - user: root
    - group: wazuh
    - mode: '0640'
    - show_changes: False
    - require:
      - pkg: wazuh-agent-package

{#- Patch the package's own <client> block in place rather than adding a
   second one: the shipped block carries a MANAGER_IP placeholder, and a
   second <client> elsewhere would leave that as an extra, broken server.
   Same blockreplace approach as formulas/wazuh — the rest of the shipped
   ossec.conf (localfile/syscheck/rootcheck) stays untouched. #}
wazuh-agent-client-block:
  file.blockreplace:
    - name: {{ wazuh_agent.ossec_conf }}
    - marker_start: '<client>'
    - marker_end: '</client>'
    - source: salt://wazuh-agent/files/ossec-agent-client.conf.j2
    - template: jinja
    - append_if_not_found: False
    - show_changes: True
    - require:
      - file: wazuh-agent-remove-legacy-block
