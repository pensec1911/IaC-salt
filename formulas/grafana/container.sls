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
      - {{ grafana.provisioning_dir }}/datasources:/etc/grafana/provisioning/datasources:ro
      - {{ grafana.provisioning_dir }}/dashboards:/etc/grafana/provisioning/dashboards:ro
      - {{ grafana.dashboards_dir }}:/var/lib/grafana-dashboards:ro
    - environment:
      - GF_SECURITY_ADMIN_USER={{ grafana.admin_user }}
      - GF_SECURITY_ADMIN_PASSWORD={{ grafana.admin_password }}
    - require:
      - sls: docker
      - file: grafana-data-dir
      - file: grafana-datasources
      - file: grafana-dashboard-provider
      - file: grafana-dashboards-dir
    - watch:
      - file: grafana-datasources
      - file: grafana-dashboard-provider
