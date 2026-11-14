{% from "healthchecks-ping/map.jinja" import hc_ping with context %}

{%- if hc_ping.enabled %}

healthchecks-ping-packages:
  pkg.installed:
    - name: {{ hc_ping.pkg }}

healthchecks-ping-config-dir:
  file.directory:
    - name: {{ hc_ping.config_dir }}
    - user: root
    - group: root
    - mode: '0700'

{#- Read from pillar inside the template, not passed as a state arg — those
   end up in the master's job cache. #}
healthchecks-ping-env:
  file.managed:
    - name: {{ hc_ping.env_file }}
    - source: salt://healthchecks-ping/files/env.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - show_changes: False
    - require:
      - file: healthchecks-ping-config-dir

healthchecks-ping-script:
  file.managed:
    - name: {{ hc_ping.script }}
    - source: salt://healthchecks-ping/files/hc-ping.sh.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - pkg: healthchecks-ping-packages
      - file: healthchecks-ping-env

{%- else %}

{#- No ping key: nothing pings, nothing is left behind. #}
healthchecks-ping-script:
  file.absent:
    - name: {{ hc_ping.script }}

healthchecks-ping-config-dir:
  file.absent:
    - name: {{ hc_ping.config_dir }}

{%- endif %}
