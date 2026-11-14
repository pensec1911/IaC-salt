{% from "toolbox/map.jinja" import toolbox with context %}
{% from "podman/macros.jinja" import container with context %}

{%- set c = toolbox.cyberchef %}
{%- set spec = {
    'name': c.container_name,
    'image': c.image,
    'tag': c.tag,
    'ports': [c.host_port ~ ':' ~ c.container_port],
} %}
{%- do spec.update(c.podman) %}
{{ container('toolbox-cyberchef-container', spec) }}
