{% from "tofu-state/map.jinja" import tofu_state with context %}

{#- An unresolved sdb reference reaches here as the URI — fail instead of
   starting postgres with it as password. #}
{%- set pw = tofu_state.db_password %}

tofu-state-secrets-valid:
{%- if not pw or pw.startswith('sdb://') %}
  test.fail_without_changes:
    - name: "tofu-state:lookup:db_password empty or unresolved — set it in OpenBao tofu-state/postgres (README)"
{%- else %}
  test.succeed_without_changes:
    - name: tofu-state:lookup:db_password is set
{%- endif %}

tofu-state-base-dir:
  file.directory:
    - name: {{ tofu_state.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Owner left to the container (:U, container.sls): only create. #}
tofu-state-data-dir:
  file.directory:
    - name: {{ tofu_state.data_dir }}
    - require:
      - file: tofu-state-base-dir

tofu-state-dump-dir:
  file.directory:
    - name: {{ tofu_state.dump_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: tofu-state-base-dir

{#- Bound alone, 0444: the container user is a sub-UID on the host. The
   0700 dir keeps host users out. #}
tofu-state-secrets-dir:
  file.directory:
    - name: {{ tofu_state.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: tofu-state-base-dir

tofu-state-secret-db_password:
  file.managed:
    - name: {{ tofu_state.secrets_dir }}/db_password
    - contents: {{ pw | yaml_encode }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: tofu-state-secrets-dir
      - test: tofu-state-secrets-valid
