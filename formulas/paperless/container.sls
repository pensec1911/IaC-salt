{% from "paperless/map.jinja" import paperless with context %}
{% from "podman/macros.jinja" import container, network with context %}

include:
  - paperless.config
{{ network('paperless-network', paperless.network) }}
{%- set net = paperless.network ~ '.network' %}
{%- set net_req = [{'cmd': 'paperless-network-daemon-reload'}, {'file': 'paperless-network'}] %}

{#- postgres runs as its image user directly (no root entrypoint), data dir
   handed to it by :U. postgres >= 18 keeps PGDATA in a versioned subdir
   below the mount. #}
{%- set postgres = {
    'name': paperless.postgres_container_name,
    'image': paperless.postgres_image,
    'tag': paperless.postgres_tag,
    'user': paperless.postgres_user,
    'network': net,
    'env': {
        'POSTGRES_DB': paperless.db_name,
        'POSTGRES_USER': paperless.db_user,
        'POSTGRES_PASSWORD_FILE': '/run/secrets/db_password',
        'TZ': paperless.timezone,
    },
    'volumes': [
        paperless.postgres_dir ~ ':/var/lib/postgresql:U',
        paperless.secrets_dir ~ '/db_password:/run/secrets/db_password:ro',
    ],
} %}
{%- do postgres.update(paperless.postgres_podman) %}
{{ container('paperless-postgres-container', postgres,
             require=net_req + [{'file': 'paperless-postgres-dir'}, {'file': 'paperless-secret-db_password'}]) }}

{#- Celery broker. AOF on: queued tasks (consumption, OCR) survive a restart. #}
{%- set valkey = {
    'name': paperless.valkey_container_name,
    'image': paperless.valkey_image,
    'tag': paperless.valkey_tag,
    'user': paperless.valkey_user,
    'network': net,
    'volumes': [paperless.valkey_dir ~ ':/data:U'],
    'command': ['valkey-server', '--appendonly', 'yes'],
} %}
{%- do valkey.update(paperless.valkey_podman) %}
{{ container('paperless-valkey-container', valkey,
             require=net_req + [{'file': 'paperless-valkey-dir'}]) }}

{#- Rootless mode upstream: started directly as uid:gid, so s6 skips its
   UID remapping and nothing needs a capability. Writable root (s6 writes
   below /run, scratch in /tmp) — podman default spec overridden in
   map.jinja. The image's entrypoint runs the DB migrations on start. #}
{%- set url_host = paperless.url.split('://')[-1].split('/')[0].split(':')[0] %}
{%- set env = {
    'PAPERLESS_URL': paperless.url,
    'PAPERLESS_ALLOWED_HOSTS': ([url_host] + paperless.allowed_hosts) | unique | join(','),
    'PAPERLESS_PROXY_SSL_HEADER': '["HTTP_X_FORWARDED_PROTO", "https"]',
    'PAPERLESS_REDIS': 'redis://' ~ paperless.valkey_container_name ~ ':6379',
    'PAPERLESS_DBENGINE': 'postgresql',
    'PAPERLESS_DBHOST': paperless.postgres_container_name,
    'PAPERLESS_DBNAME': paperless.db_name,
    'PAPERLESS_DBUSER': paperless.db_user,
    'PAPERLESS_DBPASS_FILE': '/run/secrets/db_password',
    'PAPERLESS_SECRET_KEY_FILE': '/run/secrets/secret_key',
    'PAPERLESS_TIME_ZONE': paperless.timezone,
    'PAPERLESS_OCR_LANGUAGE': paperless.ocr_language,
    'PAPERLESS_CONSUMER_POLLING_INTERVAL': paperless.consumer_polling_interval | string,
} %}
{%- set secret_names = ['secret_key', 'db_password'] %}
{%- if paperless.oidc.server_url %}
{%-   do env.update({
        'PAPERLESS_APPS': 'allauth.socialaccount.providers.openid_connect',
        'PAPERLESS_SOCIALACCOUNT_PROVIDERS_FILE': '/run/secrets/socialaccount_providers',
      }) %}
{%-   do secret_names.append('socialaccount_providers') %}
{%- endif %}
{%- do env.update(paperless.config) %}
{%- set volumes = [
    paperless.data_dir ~ ':/usr/src/paperless/data',
    paperless.media_dir ~ ':/usr/src/paperless/media',
    paperless.consume_dir ~ ':/usr/src/paperless/consume',
] %}
{%- set secret_req = [] %}
{%- for name in secret_names %}
{%-   do volumes.append(paperless.secrets_dir ~ '/' ~ name ~ ':/run/secrets/' ~ name ~ ':ro') %}
{%-   do secret_req.append({'file': 'paperless-secret-' ~ name}) %}
{%- endfor %}
{%- set dir_req = [{'file': 'paperless-data-dir'}] %}
{%- for name in ['media', 'consume'] %}
{%-   do dir_req.append({('cmd' if paperless.nfs_mount else 'file'): 'paperless-' ~ name ~ '-dir'}) %}
{%- endfor %}
{%- set backends = [paperless.postgres_container_name ~ '.service', paperless.valkey_container_name ~ '.service'] %}
{%- set web = {
    'name': paperless.container_name,
    'image': paperless.image,
    'tag': paperless.tag,
    'user': paperless.uid ~ ':' ~ paperless.gid,
    'keep_uids': [paperless.uid],
    'keep_gids': [paperless.gid],
    'network': net,
    'ports': [paperless.http_port ~ ':8000'],
    'env': env,
    'volumes': volumes,
    'unit': {'Wants': backends, 'After': backends},
} %}
{%- do web.update(paperless.podman) %}
{{ container('paperless-container', web,
             require=dir_req + [{'user': 'user-paperless'},
                                {'service': 'paperless-postgres-container'},
                                {'service': 'paperless-valkey-container'}],
             watch=secret_req) }}
