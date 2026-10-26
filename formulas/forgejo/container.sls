{% from "forgejo/map.jinja" import forgejo with context %}

include:
  - forgejo.config

{#- Rootless image: web on 3000 and Forgejo's built-in SSH server on 2222
   inside the container (image defaults), so host port 22 stays with the
   VM's own sshd. #}
forgejo-container:
  docker_container.running:
    - name: {{ forgejo.container_name }}
    - image: {{ forgejo.image }}:{{ forgejo.tag }}
    - restart_policy: unless-stopped
    - user: "{{ forgejo.uid }}:{{ forgejo.gid }}"
    - port_bindings:
      - {{ forgejo.http_port }}:3000/tcp
      - {{ forgejo.ssh_port }}:2222/tcp
    - environment:
      - TZ={{ forgejo.timezone }}
      - FORGEJO__server__SSH_PORT={{ forgejo.ssh_port }}
      {%- if forgejo.extra_ca_certs %}
      - SSL_CERT_DIR=/etc/ssl/certs:/etc/ssl/forgejo-ca
      {%- endif %}
      {%- for section, keys in forgejo.app_ini | dictsort %}
      {%- for key, value in keys | dictsort %}
      - FORGEJO__{{ section }}__{{ key }}={{ value }}
      {%- endfor %}
      {%- endfor %}
    - binds:
      - {{ forgejo.data_dir }}:/var/lib/gitea:rw
      {%- if forgejo.extra_ca_certs %}
      - {{ forgejo.ca_dir }}:/etc/ssl/forgejo-ca:ro
      {%- endif %}
    - require:
      - sls: docker
      - user: user-git
      - file: forgejo-data-dir
