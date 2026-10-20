{% from "loki/map.jinja" import loki with context %}

include:
  - loki.config

loki-container:
  docker_container.running:
    - name: {{ loki.container_name }}
    - image: {{ loki.image }}:{{ loki.tag }}
    - restart_policy: unless-stopped
    - user: "{{ loki.uid }}:{{ loki.gid }}"
    - port_bindings:
      - {{ loki.host_port }}:3100/tcp
    - binds:
      - {{ loki.config_dir }}:/etc/loki:ro
      - {{ loki.data_dir }}:/loki:rw
    - command:
      - -config.file=/etc/loki/config.yaml
    - require:
      - sls: docker
      - file: loki-data-dir
      - file: loki-config
    - watch:
      - file: loki-config
