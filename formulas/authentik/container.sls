{% from "authentik/map.jinja" import authentik with context %}
{% from "podman/macros.jinja" import container with context %}

{#- The network (`edge`) belongs to formulas/caddy, which fronts Authentik. #}
include:
  - caddy
  - authentik.config

{%- set net = authentik.network ~ '.network' %}
{%- set net_req = [{'cmd': 'caddy-network-daemon-reload'}, {'file': 'caddy-network'}] %}

{#- postgres runs as its image user directly, data dir handed to it by :U;
   password file bound alone. postgres >= 18 keeps PGDATA in a versioned
   subdir below the mount. #}
{%- set postgres = {
    'name': authentik.postgres_container_name,
    'image': authentik.postgres_image,
    'tag': authentik.postgres_tag,
    'user': authentik.postgres_user,
    'network': net,
    'env': {
        'POSTGRES_DB': authentik.db_name,
        'POSTGRES_USER': authentik.db_user,
        'POSTGRES_PASSWORD_FILE': '/run/secrets/pg_password',
    },
    'volumes': [
        authentik.postgres_dir ~ ':/var/lib/postgresql:U',
        authentik.secrets_dir ~ '/pg_password:/run/secrets/pg_password:ro',
    ],
} %}
{%- do postgres.update(authentik.postgres_podman) %}
{{ container('authentik-postgres-container', postgres,
             require=net_req + [{'file': 'authentik-postgres-dir'}, {'file': 'authentik-secret-pg_password'}]) }}

{#- Server and worker: same image, env and secrets; the worker joins the
   server's user namespace so the :U dirs keep one owner. Settings via env
   (AUTHENTIK_<SECTION>__<KEY>), secrets via file://. #}
{%- set env = {
    'AUTHENTIK_POSTGRESQL__HOST': authentik.postgres_container_name,
    'AUTHENTIK_POSTGRESQL__NAME': authentik.db_name,
    'AUTHENTIK_POSTGRESQL__USER': authentik.db_user,
    'AUTHENTIK_DISABLE_STARTUP_ANALYTICS': 'true',
    'AUTHENTIK_ERROR_REPORTING__ENABLED': 'false',
} %}
{%- do env.update({'AUTHENTIK_POSTGRESQL__PASSWORD': 'file:///run/secrets/pg_password'}) %}{#- secret-scan: allow (path of the secret file, not a value) #}
{%- do env.update({'AUTHENTIK_SECRET_KEY': 'file:///run/secrets/secret_key'}) %}{#- secret-scan: allow (path of the secret file, not a value) #}
{%- set volumes = [
    authentik.data_dir ~ ':/data:U',
    authentik.certs_dir ~ ':/certs:U',
    authentik.secrets_dir ~ '/secret_key:/run/secrets/secret_key:ro',
    authentik.secrets_dir ~ '/pg_password:/run/secrets/pg_password:ro',
] %}
{%- set secrets = [{'file': 'authentik-secret-secret_key'}, {'file': 'authentik-secret-pg_password'}] %}{#- secret-scan: allow (state IDs) #}
{%- set db = [authentik.postgres_container_name ~ '.service'] %}
{%- set server = {
    'name': authentik.container_name,
    'image': authentik.image,
    'tag': authentik.tag,
    'network': net,
    'ports': [authentik.metrics_port ~ ':9300/tcp'],
    'env': env,
    'volumes': volumes,
    'command': ['server'],
    'unit': {'Wants': db, 'After': db},
} %}
{%- do server.update(authentik.podman) %}
{{ container('authentik-server-container', server,
             require=[{'file': 'authentik-data-dir'}, {'file': 'authentik-certs-dir'},
                      {'service': 'authentik-postgres-container'}],
             watch=secrets) }}

{#- The worker applies the blueprints (mounted read-only) and gets the OIDC
   client secrets their !Env tags read — only the worker needs them. #}
{%- set worker = server.copy() %}
{%- do worker.update({
    'name': authentik.worker_container_name,
    'ports': [],
    'userns': 'container:' ~ authentik.container_name,
    'volumes': volumes + [authentik.blueprints_dir ~ ':/blueprints/homelab:ro'],
    'command': ['worker'],
    'unit': {'Requires': [authentik.container_name ~ '.service'], 'After': [authentik.container_name ~ '.service']},
    'secret_env': {},
}) %}
{%- for app, value in authentik.oidc_secrets | dictsort %}
{%-   do worker.secret_env.update({'HOMELAB_OIDC_' ~ app | upper ~ '_SECRET': value}) %}{#- secret-scan: allow (pillar value from OpenBao) #}
{%- endfor %}
{%- do worker.update(authentik.worker_podman) %}
{{ container('authentik-worker-container', worker,
             require=[{'service': 'authentik-server-container'}, {'file': 'authentik-blueprints-dir'}],
             watch=secrets) }}
