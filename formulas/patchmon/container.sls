{% from "patchmon/map.jinja" import patchmon with context %}
{% from "podman/macros.jinja" import container, network with context %}

include:
  - patchmon.config
{{ network('patchmon-network', patchmon.network) }}
{%- set net = patchmon.network ~ '.network' %}
{%- set net_req = [{'cmd': 'patchmon-network-daemon-reload'}, {'file': 'patchmon-network'}] %}

{#- POSTGRES_PASSWORD only matters when postgres initialises an empty
   postgres_dir (README "OpenBao"). Runs as its image user, data dir handed
   to it by :U — same as formulas/netbox. #}
{%- set postgres = {
    'name': patchmon.postgres_container_name,
    'image': patchmon.postgres_image,
    'tag': patchmon.postgres_tag,
    'user': patchmon.postgres_user,
    'network': net,
    'env': {
        'POSTGRES_DB': patchmon.db_name,
        'POSTGRES_USER': patchmon.db_user,
        'POSTGRES_PASSWORD_FILE': '/run/secrets/db_password',
        'TZ': patchmon.timezone,
    },
    'volumes': [
        patchmon.postgres_dir ~ ':/var/lib/postgresql/data:U',
        patchmon.secrets_dir ~ '/db_password:/run/secrets/db_password:ro',
    ],
} %}
{%- do postgres.update(patchmon.postgres_podman) %}
{{ container('patchmon-postgres-container', postgres,
             require=net_req + [{'file': 'patchmon-postgres-dir'}, {'file': 'patchmon-db-password-file'}]) }}

{#- AOF on: queued jobs survive a restart. #}
{%- set valkey = {
    'name': patchmon.valkey_container_name,
    'image': patchmon.valkey_image,
    'tag': patchmon.valkey_tag,
    'user': patchmon.valkey_user,
    'network': net,
    'volumes': [patchmon.valkey_dir ~ ':/data:U'],
    'command': ['valkey-server', '--appendonly', 'yes'],
} %}
{%- do valkey.update(patchmon.valkey_podman) %}
{{ container('patchmon-valkey-container', valkey,
             require=net_req + [{'file': 'patchmon-valkey-dir'}]) }}

{#- Secrets come from ENV_FILE (config.sls), not from here.
   hostname: a stable identity for the agent presence registry in valkey
   (upstream compose comment) — otherwise a recreated container can't
   recognise the records the old one left. #}
{%- set env = {
    'TZ': patchmon.timezone,
    'PORT': 3000,
    'CORS_ORIGIN': patchmon.cors_origin,
    'POSTGRES_HOST': patchmon.postgres_container_name,
    'POSTGRES_DB': patchmon.db_name,
    'POSTGRES_USER': patchmon.db_user,
    'ENV_FILE': '/run/secrets/patchmon.env',
    'REDIS_HOST': patchmon.valkey_container_name,
    'REDIS_PORT': 6379,
    'REDIS_DB': 0,
} %}
{%- do env.update(patchmon.env) %}
{%- set backends = [patchmon.postgres_container_name ~ '.service', patchmon.valkey_container_name ~ '.service'] %}
{%- set server = {
    'name': patchmon.container_name,
    'image': patchmon.image,
    'tag': patchmon.tag,
    'hostname': patchmon.container_name,
    'network': net,
    'ports': [patchmon.http_port ~ ':3000'],
    'env': env,
    'volumes': [patchmon.secrets_dir ~ '/patchmon.env:/run/secrets/patchmon.env:ro'],
    'unit': {'Wants': backends, 'After': backends},
} %}
{%- do server.update(patchmon.podman) %}
{{ container('patchmon-container', server,
             require=[{'service': 'patchmon-postgres-container'},
                      {'service': 'patchmon-valkey-container'}],
             watch=[{'file': 'patchmon-env-file'}]) }}
