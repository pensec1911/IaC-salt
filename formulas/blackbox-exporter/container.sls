{% from "blackbox-exporter/map.jinja" import blackbox_exporter with context %}

include:
  - blackbox-exporter.config

blackbox-exporter-container:
  docker_container.running:
    - name: {{ blackbox_exporter.container_name }}
    - image: {{ blackbox_exporter.image }}:{{ blackbox_exporter.tag }}
    - restart_policy: unless-stopped
    - user: "{{ blackbox_exporter.uid }}:{{ blackbox_exporter.gid }}"
    - port_bindings:
      - {{ blackbox_exporter.host_port }}:9115/tcp
    - binds:
      - {{ blackbox_exporter.config_dir }}:/etc/blackbox_exporter:ro
    - command:
      - --config.file=/etc/blackbox_exporter/config.yml
    - require:
      - sls: docker
      - file: blackbox-exporter-config
    - watch:
      - file: blackbox-exporter-config
