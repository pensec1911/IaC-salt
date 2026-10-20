{% from "blackbox-exporter/map.jinja" import blackbox_exporter with context %}

blackbox-exporter-config-dir:
  file.directory:
    - name: {{ blackbox_exporter.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

blackbox-exporter-config:
  file.managed:
    - name: {{ blackbox_exporter.config_dir }}/config.yml
    - source: salt://blackbox-exporter/files/config.yml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: blackbox-exporter-config-dir
