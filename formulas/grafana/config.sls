{% from "grafana/map.jinja" import grafana with context %}

grafana-data-dir:
  file.directory:
    - name: {{ grafana.data_dir }}
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0755'
    - makedirs: True
