{% from "homepage/map.jinja" import homepage with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - homepage.config

{%- set spec = {
    'name': homepage.container_name,
    'image': homepage.image,
    'tag': homepage.tag,
    'user': homepage.puid ~ ':' ~ homepage.pgid,
    'ports': [homepage.host_port ~ ':3000'],
    'tmpfs': homepage.tmpfs,
    'volumes': [
        homepage.config_dir ~ '/settings.yaml:/app/config/settings.yaml:ro',
        homepage.config_dir ~ '/services.yaml:/app/config/services.yaml:ro',
    ],
    'env': {
        'TZ': homepage.timezone,
        'HOMEPAGE_ALLOWED_HOSTS': homepage.allowed_hosts,
        'LOG_TARGETS': 'stdout',
    },
} %}
{%- do spec.update(homepage.podman) %}
{%- set files = [{'file': 'homepage-settings.yaml'}, {'file': 'homepage-services.yaml'}] %}
{{ container('homepage-container', spec, require=files, watch=files) }}
