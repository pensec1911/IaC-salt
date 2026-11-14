{% from "salt-minion/map.jinja" import salt_minion with context %}
{% from "healthchecks-ping/map.jinja" import hc_ping with context %}
{%- set dc = salt_minion.drift_check %}
{#- Ping command for the script, empty = no ping (no key in pillar). #}
{%- set ping = [hc_ping.script, dc.ping_slug ~ '-' ~ grains['id']] if hc_ping.enabled else [] %}

{%- if dc.enabled %}

salt-minion-drift-check-script:
  file.managed:
    - name: {{ dc.script }}
    - source: salt://salt-minion/files/salt-drift-check.py.j2
    - template: jinja
    - mode: '0755'
    - context:
        dc: {{ dc | json }}
        ping: {{ ping | json }}
    - require:
      - sls: node-exporter
{%- if ping %}
      - sls: healthchecks-ping
{%- endif %}

# Persisted to /etc/salt/minion.d/_schedule.conf, so it survives restarts.
# return_job off: the result is the textfile metric, not the job cache.
salt-minion-drift-check-schedule:
  schedule.present:
    - name: drift-check
    - function: cmd.run
    - job_args:
      - {{ dc.script }}
    - minutes: {{ dc.interval_minutes }}
    - splay: {{ dc.splay_seconds }}
    - return_job: False
    - require:
      - file: salt-minion-drift-check-script

{%- else %}

salt-minion-drift-check-schedule:
  schedule.absent:
    - name: drift-check

salt-minion-drift-check-script:
  file.absent:
    - name: {{ dc.script }}

salt-minion-drift-check-metrics:
  file.absent:
    - name: {{ dc.textfile_dir }}/{{ dc.metrics_file }}

{%- endif %}
