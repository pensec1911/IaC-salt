{% from "patchmon-agent/map.jinja" import agent with context %}

patchmon-agent-config-dir:
  file.directory:
    - name: {{ agent.config_dir }}
    - user: root
    - group: root
    - mode: '0700'
{%- if agent.enrolled %}

patchmon-agent-credentials:
  file.managed:
    - name: {{ agent.config_dir }}/credentials.yml
    - contents: |
        api_id: {{ agent.api_id | yaml_dquote }}
        api_key: {{ agent.api_key | yaml_dquote }}
    - user: root
    - group: root
    - mode: '0600'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: patchmon-agent-config-dir

{#- Created once; the agent owns it afterwards (map.jinja). #}
patchmon-agent-config:
  file.managed:
    - name: {{ agent.config_dir }}/config.yml
    - replace: False
    - contents: |
        patchmon_server: {{ agent.server_url | yaml_dquote }}
        api_version: "v1"
        credentials_file: "{{ agent.config_dir }}/credentials.yml"
        log_file: "{{ agent.config_dir }}/logs/patchmon-agent.log"
        log_level: {{ agent.log_level | yaml_dquote }}
        skip_ssl_verify: false
        integrations:
          docker: false
          ssh-proxy-enabled: false
          rdp-proxy-enabled: false
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: patchmon-agent-config-dir

{#- What Salt keeps enforcing in the agent-owned file. The lookahead skips
   a line that's already right, quoted or not (the agent re-marshals the
   file and may drop the quotes) — so no change, no restart, every run. #}
{%- set url_re = agent.server_url | regex_escape %}

patchmon-agent-config-server:
  file.replace:
    - name: {{ agent.config_dir }}/config.yml
    - pattern: {{ ('^patchmon_server:(?![ \t]*["\']?' ~ url_re ~ '["\']?[ \t]*$).*$') | yaml_encode }}
    - repl: {{ ('patchmon_server: ' ~ agent.server_url) | yaml_encode }}
    - require:
      - file: patchmon-agent-config
{%- for key in ['ssh-proxy-enabled', 'rdp-proxy-enabled'] %}

patchmon-agent-config-{{ key }}:
  file.replace:
    - name: {{ agent.config_dir }}/config.yml
    - pattern: '^([ \t]*){{ key }}:[ \t]*true[ \t]*$'
    - repl: '\1{{ key }}: false'
    - require:
      - file: patchmon-agent-config
{%- endfor %}
{%- endif %}
