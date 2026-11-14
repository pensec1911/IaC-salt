{% from "patchmon-agent/map.jinja" import agent with context %}

patchmon-agent-config-dir:
  file.directory:
    - name: {{ agent.config_dir }}
    - user: root
    - group: root
    - mode: '0700'
{#- Kept on every minion (tiny, no secret) so a re-enrol only needs
   credentials.yml deleted (README "Enrolment"). #}
patchmon-agent-enroll-script:
  file.managed:
    - name: {{ agent.enroll_script }}
    - source: salt://patchmon-agent/files/enroll.py
    - user: root
    - group: root
    - mode: '0700'
{%- if agent.enroll %}

{#- The token only sits on disk until enrolment succeeded (the script
   deletes it); never on the command line (ps, job cache). #}
patchmon-agent-enroll-token:
  file.managed:
    - name: {{ agent.token_file }}
    - contents: |
        {{ {'server_url': agent.server_url, 'key': agent.enroll_key, 'secret': agent.enroll_secret, 'friendly_name': grains['id']} | json }}  {# secret-scan: allow — sdb-resolved pillar #}
    - user: root
    - group: root
    - mode: '0600'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: patchmon-agent-config-dir

patchmon-agent-enroll:
  cmd.run:
    - name: {{ agent.enroll_script }} {{ agent.token_file }} {{ agent.creds_file }} {{ agent.config_dir }}/config.yml
    - creates: {{ agent.creds_file }}
    - require:
      - file: patchmon-agent-enroll-script
      - file: patchmon-agent-enroll-token
{%- else %}

{#- Left behind only by a failed enrolment run that was later fixed by hand. #}
patchmon-agent-enroll-token:
  file.absent:
    - name: {{ agent.token_file }}
{%- endif %}
{%- if agent.enrolled %}

{#- Written by the enrol script (or already there); only the mode is
   enforced — the content is the agent's identity, never rewritten. #}
patchmon-agent-credentials:
  file.managed:
    - name: {{ agent.creds_file }}
    - create: False
    - replace: False
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: patchmon-agent-config-dir
{%- if agent.enroll %}
      - cmd: patchmon-agent-enroll
{%- endif %}

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
      - file: patchmon-agent-credentials

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
