include:
  - wazuh-agent.install

{#- Same reasoning as formulas/wazuh/config.sls: patch just the blocks
   pillar drives, don't replace the package's default ossec.conf
   wholesale (it ships default localfile/syscheck monitoring too). #}
wazuh-agent-client-block:
  file.blockreplace:
    - name: /var/ossec/etc/ossec.conf
    - marker_start: "<!-- SALT-MANAGED: server + enrollment -->"
    - marker_end: "<!-- END SALT-MANAGED -->"
    - source: salt://wazuh-agent/files/ossec-agent-client.conf.j2
    - template: jinja
    - append_if_not_found: True
    - require:
      - pkg: wazuh-agent-package
