{% from "node-exporter/map.jinja" import node_exporter with context %}

node-exporter-service:
  service.running:
    - name: {{ node_exporter.service }}
    - enable: True
    - require:
      - pkg: node-exporter-package
