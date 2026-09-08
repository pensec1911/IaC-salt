{% from "homepage/map.jinja" import homepage with context %}

include:
  - homepage.config

homepage-container:
  docker_container.running:
    - name: {{ homepage.container_name }}
    - image: {{ homepage.image }}:{{ homepage.tag }}
    - restart_policy: unless-stopped
    - port_bindings:
      - {{ homepage.host_port }}:3000/tcp
    - binds:
      - {{ homepage.config_dir }}:/app/config:rw
    - environment:
      - PUID={{ homepage.puid }}
      - PGID={{ homepage.pgid }}
      - TZ={{ homepage.timezone }}
    - require:
      - sls: docker
      - file: homepage-settings.yaml
      - file: homepage-services.yaml
    - watch:
      - file: homepage-settings.yaml
      - file: homepage-services.yaml
