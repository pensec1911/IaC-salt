{% from "headscale/map.jinja" import headscale with context %}

{#- Without a server_url clients get a broken login URL, without a
   base_domain Headscale refuses to start — fail the formula instead. #}
{%- set missing = [] %}
{%- for key in ['server_url', 'base_domain'] %}
{%-   if not headscale[key] %}{% do missing.append(key) %}{% endif %}
{%- endfor %}

headscale-config-valid:
{%- if missing %}
  test.fail_without_changes:
    - name: "headscale:lookup {{ missing | join(', ') }} not set (README)"
{%- else %}
  test.succeed_without_changes:
    - name: headscale:lookup is complete
{%- endif %}

headscale-base-dir:
  file.directory:
    - name: {{ headscale.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Config, policy and DNS records: root-owned, readable by the headscale
   group (gid mapped 1:1), mounted read-only. #}
headscale-config-dir:
  file.directory:
    - name: {{ headscale.config_dir }}
    - user: root
    - group: {{ headscale.gid }}
    - mode: '0750'
    - require:
      - file: headscale-base-dir
      - user: user-headscale

{#- SQLite DB, noise/DERP private keys, the ACME cache, the CLI socket. #}
headscale-data-dir:
  file.directory:
    - name: {{ headscale.data_dir }}
    - user: {{ headscale.uid }}
    - group: {{ headscale.gid }}
    - mode: '0750'
    - require:
      - file: headscale-base-dir
      - user: user-headscale

headscale-config.yaml:
  file.managed:
    - name: {{ headscale.config_dir }}/config.yaml
    - source: salt://headscale/files/config.yaml.j2
    - template: jinja
    - user: root
    - group: {{ headscale.gid }}
    - mode: '0640'
    - require:
      - test: headscale-config-valid
      - file: headscale-config-dir

headscale-policy:
  file.managed:
    - name: {{ headscale.config_dir }}/policy.hujson
    - contents: |
        {{ headscale.policy | tojson(indent=2) | indent(8) }}
    - user: root
    - group: {{ headscale.gid }}
    - mode: '0640'
    - require:
      - file: headscale-config-dir

{#- Headscale watches this file (dns.extra_records_path), but Salt replaces
   it (new inode, group/mode set after the rename): the watcher hits
   "permission denied" on the fresh file and gives up for good
   (2026-11-26). So a change restarts the container instead (container.sls
   watch) — clients reconnect within seconds. #}
headscale-extra-records:
  file.managed:
    - name: {{ headscale.config_dir }}/extra-records.json
    - contents: |
        {{ headscale.extra_records | tojson(indent=2) | indent(8) }}
    - user: root
    - group: {{ headscale.gid }}
    - mode: '0640'
    - require:
      - file: headscale-config-dir
