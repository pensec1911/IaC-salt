{% from "forgejo-runner/map.jinja" import runner with context %}

include:
  - forgejo-runner.config
{%- if runner.secret_valid %}

forgejo-runner-network:
  docker_network.present:
    - name: {{ runner.network }}
    - require:
      - sls: docker

{#- Plain TCP without TLS: reachable only on the private network, where the
   runner is the only other member — job containers live inside dind. #}
forgejo-runner-dind-container:
  docker_container.running:
    - name: {{ runner.dind_container_name }}
    - image: {{ runner.dind_image }}:{{ runner.dind_tag }}
    - restart_policy: unless-stopped
    - privileged: True
    - command: dockerd -H tcp://0.0.0.0:{{ runner.dind_port }} --tls=false
    - environment:
      - DOCKER_TLS_CERTDIR=
    - networks:
      - {{ runner.network }}
    - binds:
      - {{ runner.dind_dir }}:/var/lib/docker:rw
    - require:
      - sls: docker
      - docker_network: forgejo-runner-network
      - file: forgejo-runner-dind-dir

forgejo-runner-container:
  docker_container.running:
    - name: {{ runner.container_name }}
    - image: {{ runner.image }}:{{ runner.tag }}
    - restart_policy: unless-stopped
    - user: "{{ runner.uid }}:{{ runner.gid }}"
    - command: forgejo-runner daemon --config /data/config.yml
    - environment:
      - DOCKER_HOST=tcp://{{ runner.dind_container_name }}:{{ runner.dind_port }}
    - networks:
      - {{ runner.network }}
    - binds:
      - {{ runner.data_dir }}:/data:rw
    - require:
      - sls: docker
      - user: user-forgejo-runner
      - docker_container: forgejo-runner-dind-container
    - watch:
      - file: forgejo-runner-config
      - file: forgejo-runner-token
{%- endif %}
