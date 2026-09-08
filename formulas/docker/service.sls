{% from "docker/map.jinja" import docker with context %}

docker-service:
  service.running:
    - name: {{ docker.service }}
    - enable: True
    - require:
      - pkg: docker-packages
