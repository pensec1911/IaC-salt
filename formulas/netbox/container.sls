{% from "netbox/map.jinja" import netbox with context %}
{% from "podman/macros.jinja" import container, network with context %}

include:
  - netbox.config
{{ network('netbox-network', netbox.network) }}
{%- set net = netbox.network ~ '.network' %}
{%- set net_req = [{'cmd': 'netbox-network-daemon-reload'}, {'file': 'netbox-network'}] %}

{#- postgres runs as its image user directly (no root entrypoint, no chown),
   data dir handed to it by :U. Secret file bound alone (0444; its 0700 dir
   keeps host users out). postgres >= 18 keeps PGDATA in a versioned subdir
   below the mount. #}
{%- set postgres = {
    'name': netbox.postgres_container_name,
    'image': netbox.postgres_image,
    'tag': netbox.postgres_tag,
    'user': netbox.postgres_user,
    'network': net,
    'env': {
        'POSTGRES_DB': netbox.db_name,
        'POSTGRES_USER': netbox.db_user,
        'POSTGRES_PASSWORD_FILE': '/run/secrets/db_password',
        'TZ': netbox.timezone,
    },
    'volumes': [
        netbox.postgres_dir ~ ':/var/lib/postgresql:U',
        netbox.secrets_dir ~ '/db_password:/run/secrets/db_password:ro',
    ],
} %}
{%- do postgres.update(netbox.postgres_podman) %}
{{ container('netbox-postgres-container', postgres,
             require=net_req + [{'file': 'netbox-postgres-dir'}, {'file': 'netbox-secret-db_password'}]) }}

{#- AOF on: queued jobs survive a restart. #}
{%- set valkey = {
    'name': netbox.valkey_container_name,
    'image': netbox.valkey_image,
    'tag': netbox.valkey_tag,
    'user': netbox.valkey_user,
    'network': net,
    'volumes': [netbox.valkey_dir ~ ':/data:U'],
    'command': ['valkey-server', '--appendonly', 'yes'],
} %}
{%- do valkey.update(netbox.valkey_podman) %}
{{ container('netbox-valkey-container', valkey,
             require=net_req + [{'file': 'netbox-valkey-dir'}]) }}

{#- Same image, env and binds for web and worker; the entrypoint of the web
   container runs the DB migrations, the worker just retries until they're
   done (Restart=always). The worker shares the web container's user
   namespace: media_dir is handed to that mapping by :U, and a second
   mapping would take it away again on every start. #}
{%- set env = {
    'TZ': netbox.timezone,
    'DB_HOST': netbox.postgres_container_name,
    'DB_NAME': netbox.db_name,
    'DB_USER': netbox.db_user,
    'REDIS_HOST': netbox.valkey_container_name,
    'REDIS_DATABASE': 0,
    'REDIS_CACHE_HOST': netbox.valkey_container_name,
    'REDIS_CACHE_DATABASE': 1,
    'MEDIA_ROOT': '/opt/netbox/netbox/media',
} %}
{%- do env.update(netbox.config) %}
{%- set volumes = [netbox.media_dir ~ ':/opt/netbox/netbox/media:U'] %}
{%- for name in netbox.secret_names %}
{%-   do volumes.append(netbox.secrets_dir ~ '/' ~ name ~ ':/run/secrets/' ~ name ~ ':ro') %}
{%- endfor %}
{%- set secrets = [] %}
{%- for name in netbox.secret_names %}{% do secrets.append({'file': 'netbox-secret-' ~ name}) %}{% endfor %}
{%- set backends = [netbox.postgres_container_name ~ '.service', netbox.valkey_container_name ~ '.service'] %}
{%- set web = {
    'name': netbox.container_name,
    'image': netbox.image,
    'tag': netbox.tag,
    'user': netbox.media_uid ~ ':' ~ netbox.media_gid,
    'network': net,
    'ports': [netbox.http_port ~ ':8080'],
    'env': env,
    'volumes': volumes,
    'unit': {'Wants': backends, 'After': backends},
} %}
{%- do web.update(netbox.podman) %}
{{ container('netbox-container', web,
             require=[{'file': 'netbox-media-dir'},
                      {'service': 'netbox-postgres-container'},
                      {'service': 'netbox-valkey-container'}],
             watch=secrets) }}

{%- set worker = web.copy() %}
{%- do worker.update({
    'name': netbox.worker_container_name,
    'ports': [],
    'userns': 'container:' ~ netbox.container_name,
    'network': net,
    'command': ['/opt/netbox/venv/bin/python', '/opt/netbox/netbox/manage.py', 'rqworker'],
    'unit': {'Requires': [netbox.container_name ~ '.service'], 'After': [netbox.container_name ~ '.service']},
}) %}
{{ container('netbox-worker-container', worker,
             require=[{'service': 'netbox-container'}],
             watch=secrets) }}
