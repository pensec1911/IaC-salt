{% from "alertmanager/map.jinja" import alertmanager with context %}

alertmanager-config-dir:
  file.directory:
    - name: {{ alertmanager.config_dir }}
    - user: {{ alertmanager.uid }}
    - group: {{ alertmanager.gid }}
    - mode: '0755'
    - makedirs: True

alertmanager-data-dir:
  file.directory:
    - name: {{ alertmanager.data_dir }}
    - user: {{ alertmanager.uid }}
    - group: {{ alertmanager.gid }}
    - mode: '0755'
    - makedirs: True

{#- 0640: receivers can carry tokens/passwords (resolved from OpenBao). #}
alertmanager.yml:
  file.managed:
    - name: {{ alertmanager.config_dir }}/alertmanager.yml
    - source: salt://alertmanager/files/alertmanager.yml.j2
    - template: jinja
    - user: {{ alertmanager.uid }}
    - group: {{ alertmanager.gid }}
    - mode: '0640'
    - show_changes: False
    - require:
      - file: alertmanager-config-dir
