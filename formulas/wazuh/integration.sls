{% from "wazuh/map.jinja" import wazuh with context %}
{%- set am = wazuh.alertmanager %}
{%- if am.url %}

include:
  - wazuh.manager

{#- integratord runs integrations/<name> with (alert file, api_key,
   hook_url); the wrapper hands that to the .py with Wazuh's bundled
   Python, like the shipped slack/pagerduty pairs. Owner/mode as theirs. #}
wazuh-alertmanager-wrapper:
  file.managed:
    - name: {{ am.integrations_dir }}/{{ am.name }}
    - mode: '0750'
    - user: root
    - group: wazuh
    - contents: |
        #!/bin/sh
        # Managed by Salt (formulas/wazuh) — do not edit.
        exec {{ am.python }} "$0.py" "$@"
    - require:
      - pkg: wazuh-manager-package

wazuh-alertmanager-script:
  file.managed:
    - name: {{ am.integrations_dir }}/{{ am.name }}.py
    - source: salt://wazuh/files/custom-alertmanager.py.j2
    - template: jinja
    - mode: '0750'
    - user: root
    - group: wazuh
    - require:
      - pkg: wazuh-manager-package

{#- ossec.conf has no shipped <integration> block to patch, so this one is
   appended as its own <ossec_config> section — the manager merges several
   (the shipped file already has two). Never a bare <integration> after the
   last </ossec_config>: that is rejected (see manager.sls). #}
wazuh-alertmanager-integration-block:
  file.blockreplace:
    - name: /var/ossec/etc/ossec.conf
    - marker_start: '<!-- SALT-MANAGED: alertmanager integration -->'
    - marker_end: '<!-- END SALT-MANAGED: alertmanager integration -->'
    - content: |
        <ossec_config>
          <integration>
            <name>{{ am.name }}</name>
            <hook_url>{{ am.url }}</hook_url>
            <level>{{ am.level }}</level>
            <alert_format>json</alert_format>
          </integration>
        </ossec_config>
    - append_if_not_found: True
    - require:
      - file: wazuh-alertmanager-wrapper
      - file: wazuh-alertmanager-script
      - file: wazuh-manager-auth-use-password
    - watch_in:
      - service: wazuh-manager-service

{%- endif %}
