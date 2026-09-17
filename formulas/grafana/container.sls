{% from "grafana/map.jinja" import grafana with context %}

include:
  - grafana.config

grafana-container:
  docker_container.running:
    - name: {{ grafana.container_name }}
    - image: {{ grafana.image }}:{{ grafana.tag }}
    - restart_policy: unless-stopped
    - user: "{{ grafana.uid }}:{{ grafana.gid }}"
    - port_bindings:
      - {{ grafana.host_port }}:3000/tcp
    - binds:
      - {{ grafana.data_dir }}:/var/lib/grafana:rw
    - environment:
      - GF_SECURITY_ADMIN_USER={{ grafana.admin_user }}
      - GF_SECURITY_ADMIN_PASSWORD={{ grafana.admin_password }}
    - require:
      - sls: docker
      - file: grafana-data-dir
