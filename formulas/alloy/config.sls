{% from "alloy/map.jinja" import alloy with context %}

alloy-config-dir:
  file.directory:
    - name: {{ alloy.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

alloy-data-dir:
  file.directory:
    - name: {{ alloy.data_dir }}
    - user: root
    - group: root
    - mode: '0750'
    - makedirs: True

alloy-config:
  file.managed:
    - name: {{ alloy.config_dir }}/config.alloy
    - source: salt://alloy/files/config.alloy.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: alloy-config-dir
