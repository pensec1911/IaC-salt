{% from "oxidized/map.jinja" import oxidized with context %}
{% from "podman/macros.jinja" import container with context %}
{%- if oxidized.enabled %}

include:
  - oxidized.config

{#- oxidized itself as the image's oxidized user instead of the image's
   runit-as-root start (map.jinja), behind its dumb-init entrypoint.
   OXIDIZED_HOME: where it reads config + router.db; OXIDIZED_LOGS: where a
   crash file goes; HOME: $HOME/.ssh/known_hosts for libgit2 and net-ssh.
   No keep_uids: 30000 is no host account, and --userns=auto sizes the
   namespace to cover the image's ids and `user` (like blackbox-exporter's
   65534) — the data dir goes to the mapping via :U. #}
{%- set volumes = [
    oxidized.config_dir ~ ':' ~ oxidized.container_home ~ ':ro',
    oxidized.data_dir ~ ':' ~ oxidized.container_data ~ ':U',
    oxidized.secrets_dir ~ '/forgejo:' ~ oxidized.container_keys ~ '/forgejo:ro',
    oxidized.secrets_dir ~ '/forgejo.pub:' ~ oxidized.container_keys ~ '/forgejo.pub:ro',
] %}
{%- set watch = [
    {'file': 'oxidized-config'},
    {'file': 'oxidized-router-db'},
    {'file': 'oxidized-known-hosts'},
    {'file': 'oxidized-key-forgejo'},
    {'file': 'oxidized-key-forgejo.pub'},
] %}
{%- for name in oxidized.devices | sort %}
{%-   do volumes.append(oxidized.secrets_dir ~ '/device-' ~ name ~ ':' ~ oxidized.container_keys ~ '/device-' ~ name ~ ':ro') %}
{%-   do watch.append({'file': 'oxidized-key-device-' ~ name}) %}
{%- endfor %}

{%- set spec = {
    'name': oxidized.container_name,
    'image': oxidized.image,
    'tag': oxidized.tag,
    'user': oxidized.uid ~ ':' ~ oxidized.gid,
    'ports': [oxidized.host_port ~ ':' ~ oxidized.container_port],
    'volumes': volumes,
    'env': {
        'HOME': oxidized.container_home,
        'OXIDIZED_HOME': oxidized.container_home,
        'OXIDIZED_LOGS': oxidized.container_data,
    },
    'command': ['oxidized'],
} %}
{%- do spec.update(oxidized.podman) %}
{{ container('oxidized-container', spec,
             require=[{'test': 'oxidized-config-valid'}, {'file': 'oxidized-data-dir'}],
             watch=watch) }}
{%- endif %}
