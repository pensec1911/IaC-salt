{% from "openbao-snapshot/map.jinja" import openbao_snapshot as ob with context %}

{#- Without addr/role_id the job can't work — fail instead of installing a
   timer that fails every night. #}
openbao-snapshot-config-valid:
{%- if ob.addr and ob.role_id %}
  test.succeed_without_changes:
    - name: openbao_snapshot:lookup addr and role_id are set
{%- else %}
  test.fail_without_changes:
    - name: "openbao_snapshot:lookup:addr and role_id must be set (pillar/openbao-snapshot.sls)"
{%- endif %}

openbao-snapshot-config-dir:
  file.directory:
    - name: {{ ob.config_dir }}
    - user: root
    - group: root
    - mode: '0700'

{#- Placed by hand (README "Bootstrap") — Salt never sees the value. #}
openbao-snapshot-secret-id:
  file.exists:
    - name: {{ ob.secret_id_file }}
    - require:
      - file: openbao-snapshot-config-dir

openbao-snapshot-secret-id-perms:
  file.managed:
    - name: {{ ob.secret_id_file }}
    - replace: False
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - file: openbao-snapshot-secret-id

openbao-snapshot-target-dir:
  file.directory:
    - name: {{ ob.target_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - makedirs: True
