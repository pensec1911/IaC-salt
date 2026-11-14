{% from "healthchecks/map.jinja" import healthchecks with context %}

include:
  - healthchecks.container

{#- Checks as code: upserts healthchecks:lookup:checks through the Management
   API (unique by slug). Only once the project API key is in OpenBao — before
   that, pings still auto-create their checks (with the default 1 day / 1 h)
   and nothing here runs. The run is skipped while the stamp matches the
   rendered list; a failed run leaves the stamp, so the next apply retries. #}
{%- if healthchecks.provision %}

healthchecks-provision-dir:
  file.directory:
    - name: {{ healthchecks.provision_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: healthchecks-base-dir

{#- Read from pillar inside the template, not passed as a state arg — those
   end up in the master's job cache. #}
healthchecks-provision-api-key:
  file.managed:
    - name: {{ healthchecks.provision_dir }}/api_key
    - source: salt://healthchecks/files/api_key.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - show_changes: False
    - require:
      - file: healthchecks-provision-dir

healthchecks-provision-checks:
  file.serialize:
    - name: {{ healthchecks.provision_dir }}/checks.json
    - dataset: {{ healthchecks.checks | json }}
    - serializer: json
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: healthchecks-provision-dir

healthchecks-provision-script:
  file.managed:
    - name: {{ healthchecks.provision_script }}
    - source: salt://healthchecks/files/healthchecks-provision.py.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0755'

healthchecks-provision:
  cmd.run:
    - name: {{ healthchecks.provision_script }}
    - unless: {{ healthchecks.provision_script }} --is-current
    - require:
      - file: healthchecks-provision-api-key
      - file: healthchecks-provision-checks
      - file: healthchecks-provision-script
      - service: healthchecks-container

{%- else %}

healthchecks-provision:
  test.succeed_without_changes:
    - name: "healthchecks:lookup:api_key not set — checks are not provisioned (README \"Checks as code\")"

{%- endif %}
