{% from "docker/map.jinja" import docker with context %}

docker-daemon-config:
  file.serialize:
    - name: {{ docker.daemon_config_file }}
    - serializer: json
    - dataset: {{ docker.daemon_config | json }}
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - require:
      - pkg: docker-packages
    - watch_in:
      - service: docker-service
