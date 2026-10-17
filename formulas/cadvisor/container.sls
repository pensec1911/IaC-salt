{% from "cadvisor/map.jinja" import cadvisor with context %}

{#- Privileged + the read-only host binds are what cAdvisor's own docs ask
   for; without them it can't see cgroups or the Docker metadata. #}
cadvisor-container:
  docker_container.running:
    - name: {{ cadvisor.container_name }}
    - image: {{ cadvisor.image }}:{{ cadvisor.tag }}
    - restart_policy: unless-stopped
    - privileged: True
    - devices:
      - /dev/kmsg
    - port_bindings:
      - {{ cadvisor.host_port }}:8080/tcp
    - binds:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    - command:
      - --docker_only=true
      - --housekeeping_interval={{ cadvisor.housekeeping_interval }}
    - require:
      - sls: docker
