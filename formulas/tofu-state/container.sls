{% from "tofu-state/map.jinja" import tofu_state with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - tofu-state.config

{#- POSTGRES_PASSWORD_FILE is only read on first init of data_dir; a changed
   password afterwards needs ALTER ROLE by hand (README). postgres >= 18
   keeps PGDATA in a versioned subdir below the mount. #}
{%- set spec = {
    'name': tofu_state.container_name,
    'image': tofu_state.image,
    'tag': tofu_state.tag,
    'user': tofu_state.postgres_user,
    'ports': [tofu_state.postgres_port ~ ':5432'],
    'env': {
        'POSTGRES_DB': tofu_state.db_name,
        'POSTGRES_USER': tofu_state.db_user,
        'POSTGRES_PASSWORD_FILE': '/run/secrets/db_password',
        'TZ': tofu_state.timezone,
    },
    'volumes': [
        tofu_state.data_dir ~ ':/var/lib/postgresql:U',
        tofu_state.secrets_dir ~ '/db_password:/run/secrets/db_password:ro',
    ],
} %}
{%- do spec.update(tofu_state.podman) %}
{{ container('tofu-state-container', spec,
             require=[{'file': 'tofu-state-data-dir'}, {'file': 'tofu-state-secret-db_password'}]) }}
