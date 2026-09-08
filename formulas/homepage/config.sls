{% from "homepage/map.jinja" import homepage with context %}

homepage-config-dir:
  file.directory:
    - name: {{ homepage.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

homepage-settings.yaml:
  file.managed:
    - name: {{ homepage.config_dir }}/settings.yaml
    - source: salt://homepage/files/settings.yaml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: homepage-config-dir

homepage-services.yaml:
  file.managed:
    - name: {{ homepage.config_dir }}/services.yaml
    - source: salt://homepage/files/services.yaml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: homepage-config-dir
