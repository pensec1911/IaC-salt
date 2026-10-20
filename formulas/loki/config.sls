{% from "loki/map.jinja" import loki with context %}

loki-config-dir:
  file.directory:
    - name: {{ loki.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

loki-data-dir:
  file.directory:
    - name: {{ loki.data_dir }}
    - user: {{ loki.uid }}
    - group: {{ loki.gid }}
    - mode: '0750'
    - makedirs: True

loki-config:
  file.managed:
    - name: {{ loki.config_dir }}/config.yaml
    - source: salt://loki/files/config.yaml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: loki-config-dir
