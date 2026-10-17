{% from "alertmanager/map.jinja" import alertmanager with context %}

include:
  - alertmanager.config

alertmanager-container:
  docker_container.running:
    - name: {{ alertmanager.container_name }}
    - image: {{ alertmanager.image }}:{{ alertmanager.tag }}
    - restart_policy: unless-stopped
    - user: "{{ alertmanager.uid }}:{{ alertmanager.gid }}"
    - port_bindings:
      - {{ alertmanager.host_port }}:9093/tcp
    - binds:
      - {{ alertmanager.config_dir }}:/etc/alertmanager:ro
      - {{ alertmanager.data_dir }}:/alertmanager:rw
    - command:
      - --config.file=/etc/alertmanager/alertmanager.yml
      - --storage.path=/alertmanager
    - require:
      - sls: docker
      - file: alertmanager-data-dir
      - file: alertmanager.yml
    - watch:
      - file: alertmanager.yml
