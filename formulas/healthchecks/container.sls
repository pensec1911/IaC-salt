{% from "healthchecks/map.jinja" import healthchecks with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - healthchecks.config

{#- uid/gid mapped 1:1: data_dir stays owned by them on the host. All state is
   in /data (SQLite); the app itself only needs the tmpfs /tmp, so the
   default read-only root fits. SECRET_KEY goes through the 0600 secret env
   file, not the unit. The image's run.sh migrates the DB, then starts
   gunicorn (:8000), sendalerts and sendreports. #}
{%- set host = healthchecks.site_root.split('://')[-1].split('/')[0].split(':')[0] %}
{%- set hosts = [host] + healthchecks.allowed_hosts + ['localhost', '127.0.0.1'] %}
{%- set env = {
    'SITE_ROOT': healthchecks.site_root,
    'ALLOWED_HOSTS': hosts | unique | join(','),
} %}
{%- do env.update(healthchecks.env) %}
{%- set spec = {
    'name': healthchecks.container_name,
    'image': healthchecks.image,
    'tag': healthchecks.tag,
    'user': healthchecks.uid ~ ':' ~ healthchecks.gid,
    'keep_uids': [healthchecks.uid],
    'keep_gids': [healthchecks.gid],
    'ports': [healthchecks.http_port ~ ':8000'],
    'volumes': [healthchecks.data_dir ~ ':/data:rw'],
    'env': env,
    'secret_env': {},
} %}
{%- do spec.secret_env.update({'SECRET_KEY': healthchecks.secret_key}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.update(healthchecks.podman) %}
{{ container('healthchecks-container', spec,
             require=[{'user': 'user-healthchecks'}, {'file': 'healthchecks-data-dir'}, {'test': 'healthchecks-config-valid'}]) }}
