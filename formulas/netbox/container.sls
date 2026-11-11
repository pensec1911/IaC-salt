{% from "netbox/map.jinja" import netbox with context %}

include:
  - netbox.config

netbox-network:
  docker_network.present:
    - name: {{ netbox.network }}
    - require:
      - sls: docker

netbox-postgres-container:
  docker_container.running:
    - name: {{ netbox.postgres_container_name }}
    - image: {{ netbox.postgres_image }}:{{ netbox.postgres_tag }}
    - restart_policy: unless-stopped
    - environment:
      - POSTGRES_DB={{ netbox.db_name }}
      - POSTGRES_USER={{ netbox.db_user }}
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
      - TZ={{ netbox.timezone }}
    - networks:
      - {{ netbox.network }}
    {#- postgres >= 18 keeps PGDATA in a versioned subdir below this. #}
    - binds:
      - {{ netbox.postgres_dir }}:/var/lib/postgresql:rw
      - {{ netbox.secrets_dir }}/db_password:/run/secrets/db_password:ro
    - require:
      - sls: docker
      - docker_network: netbox-network
      - file: netbox-postgres-dir
      - file: netbox-secret-db_password

{#- AOF on: queued jobs survive a restart. #}
netbox-valkey-container:
  docker_container.running:
    - name: {{ netbox.valkey_container_name }}
    - image: {{ netbox.valkey_image }}:{{ netbox.valkey_tag }}
    - restart_policy: unless-stopped
    - command: valkey-server --appendonly yes
    - networks:
      - {{ netbox.network }}
    - binds:
      - {{ netbox.valkey_dir }}:/data:rw
    - require:
      - sls: docker
      - docker_network: netbox-network
      - file: netbox-valkey-dir

{#- Same image, env and binds for web and worker; the entrypoint of the web
   container runs the DB migrations, the worker just retries until they're
   done (restart policy). #}
{%- set environment = [
    'TZ=' ~ netbox.timezone,
    'DB_HOST=' ~ netbox.postgres_container_name,
    'DB_NAME=' ~ netbox.db_name,
    'DB_USER=' ~ netbox.db_user,
    'REDIS_HOST=' ~ netbox.valkey_container_name,
    'REDIS_DATABASE=0',
    'REDIS_CACHE_HOST=' ~ netbox.valkey_container_name,
    'REDIS_CACHE_DATABASE=1',
    'MEDIA_ROOT=/opt/netbox/netbox/media',
] %}
{%- for key, value in netbox.config | dictsort %}
{%-   do environment.append(key ~ '=' ~ value) %}
{%- endfor %}
{%- set binds = [
    netbox.media_dir ~ ':/opt/netbox/netbox/media:rw',
    netbox.secrets_dir ~ ':/run/secrets:ro',
] %}

netbox-container:
  docker_container.running:
    - name: {{ netbox.container_name }}
    - image: {{ netbox.image }}:{{ netbox.tag }}
    - restart_policy: unless-stopped
    - user: "{{ netbox.media_uid }}:{{ netbox.media_gid }}"
    - port_bindings:
      - {{ netbox.http_port }}:8080/tcp
    - environment: {{ environment | json }}
    - networks:
      - {{ netbox.network }}
    - binds: {{ binds | json }}
    - require:
      - sls: docker
      - file: netbox-media-dir
      - docker_container: netbox-postgres-container
      - docker_container: netbox-valkey-container
    - watch:
      - file: netbox-secret-secret_key
      - file: netbox-secret-db_password
      - file: netbox-secret-api_token_pepper_1

netbox-worker-container:
  docker_container.running:
    - name: {{ netbox.worker_container_name }}
    - image: {{ netbox.image }}:{{ netbox.tag }}
    - restart_policy: unless-stopped
    - user: "{{ netbox.media_uid }}:{{ netbox.media_gid }}"
    - command: /opt/netbox/venv/bin/python /opt/netbox/netbox/manage.py rqworker
    - environment: {{ environment | json }}
    - networks:
      - {{ netbox.network }}
    - binds: {{ binds | json }}
    - require:
      - docker_container: netbox-container
    - watch:
      - file: netbox-secret-secret_key
      - file: netbox-secret-db_password
      - file: netbox-secret-api_token_pepper_1
