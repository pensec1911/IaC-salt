{% from "patchmon/map.jinja" import patchmon with context %}

include:
  - patchmon.config

patchmon-network:
  docker_network.present:
    - name: {{ patchmon.network }}
    - require:
      - sls: docker

{#- POSTGRES_PASSWORD only matters when postgres initialises an empty
   postgres_dir (README "OpenBao"). #}
patchmon-postgres-container:
  docker_container.running:
    - name: {{ patchmon.postgres_container_name }}
    - image: {{ patchmon.postgres_image }}:{{ patchmon.postgres_tag }}
    - restart_policy: unless-stopped
    - environment:
      - POSTGRES_DB={{ patchmon.db_name }}
      - POSTGRES_USER={{ patchmon.db_user }}
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_password
      - TZ={{ patchmon.timezone }}
    - networks:
      - {{ patchmon.network }}
    - binds:
      - {{ patchmon.postgres_dir }}:/var/lib/postgresql/data:rw
      - {{ patchmon.secrets_dir }}/db_password:/run/secrets/db_password:ro
    - require:
      - sls: docker
      - docker_network: patchmon-network
      - file: patchmon-postgres-dir
      - file: patchmon-db-password-file

{#- AOF on: queued jobs survive a restart. #}
patchmon-valkey-container:
  docker_container.running:
    - name: {{ patchmon.valkey_container_name }}
    - image: {{ patchmon.valkey_image }}:{{ patchmon.valkey_tag }}
    - restart_policy: unless-stopped
    - command: valkey-server --appendonly yes
    - networks:
      - {{ patchmon.network }}
    - binds:
      - {{ patchmon.valkey_dir }}:/data:rw
    - require:
      - sls: docker
      - docker_network: patchmon-network
      - file: patchmon-valkey-dir

{#- Secrets come from ENV_FILE (config.sls), not from here.
   hostname: a stable identity for the agent presence registry in valkey
   (upstream compose comment) — otherwise a recreated container can't
   recognise the records the old one left. #}
{%- set environment = [
    'TZ=' ~ patchmon.timezone,
    'PORT=3000',
    'CORS_ORIGIN=' ~ patchmon.cors_origin,
    'POSTGRES_HOST=' ~ patchmon.postgres_container_name,
    'POSTGRES_DB=' ~ patchmon.db_name,
    'POSTGRES_USER=' ~ patchmon.db_user,
    'ENV_FILE=/run/secrets/patchmon.env',
    'REDIS_HOST=' ~ patchmon.valkey_container_name,
    'REDIS_PORT=6379',
    'REDIS_DB=0',
] %}
{%- for key, value in patchmon.env | dictsort %}
{%-   do environment.append(key ~ '=' ~ value) %}
{%- endfor %}

patchmon-container:
  docker_container.running:
    - name: {{ patchmon.container_name }}
    - image: {{ patchmon.image }}:{{ patchmon.tag }}
    - restart_policy: unless-stopped
    - hostname: {{ patchmon.container_name }}
    - port_bindings:
      - {{ patchmon.http_port }}:3000/tcp
    - environment: {{ environment | json }}
    - networks:
      - {{ patchmon.network }}
    - binds:
      - {{ patchmon.secrets_dir }}/patchmon.env:/run/secrets/patchmon.env:ro
    - require:
      - sls: docker
      - docker_container: patchmon-postgres-container
      - docker_container: patchmon-valkey-container
    - watch:
      - file: patchmon-env-file
