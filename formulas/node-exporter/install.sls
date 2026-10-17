{% from "node-exporter/map.jinja" import node_exporter with context %}

node-exporter-package:
  pkg.installed:
    - name: {{ node_exporter.pkg }}
    - install_recommends: {{ node_exporter.install_recommends }}
