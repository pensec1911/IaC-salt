{% from "prometheus/map.jinja" import prometheus with context %}

include:
  - prometheus.config

prometheus-container:
  docker_container.running:
    - name: {{ prometheus.container_name }}
    - image: {{ prometheus.image }}:{{ prometheus.tag }}
    - restart_policy: unless-stopped
    - user: "{{ prometheus.uid }}:{{ prometheus.gid }}"
    - port_bindings:
      - {{ prometheus.host_port }}:9090/tcp
    - binds:
      - {{ prometheus.config_dir }}:/etc/prometheus:ro
      - {{ prometheus.data_dir }}:/prometheus:rw
    - command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time={{ prometheus.retention }}
    - require:
      - sls: docker
      - file: prometheus-data-dir
      - file: prometheus.yml
    - watch:
      - file: prometheus.yml
