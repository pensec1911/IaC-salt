{% from "prometheus/map.jinja" import prometheus with context %}

prometheus-config-dir:
  file.directory:
    - name: {{ prometheus.config_dir }}
    - user: {{ prometheus.uid }}
    - group: {{ prometheus.gid }}
    - mode: '0755'
    - makedirs: True

prometheus-data-dir:
  file.directory:
    - name: {{ prometheus.data_dir }}
    - user: {{ prometheus.uid }}
    - group: {{ prometheus.gid }}
    - mode: '0755'
    - makedirs: True

prometheus.yml:
  file.managed:
    - name: {{ prometheus.config_dir }}/prometheus.yml
    - source: salt://prometheus/files/prometheus.yml.j2
    - template: jinja
    - user: {{ prometheus.uid }}
    - group: {{ prometheus.gid }}
    - mode: '0644'
    - require:
      - file: prometheus-config-dir

{#- Always rendered (an empty group list is valid), so prometheus.yml can
   reference it unconditionally. #}
prometheus-rules:
  file.managed:
    - name: {{ prometheus.config_dir }}/{{ prometheus.rules_file }}
    - source: salt://prometheus/files/rules.yml.j2
    - template: jinja
    - user: {{ prometheus.uid }}
    - group: {{ prometheus.gid }}
    - mode: '0644'
    - require:
      - file: prometheus-config-dir
