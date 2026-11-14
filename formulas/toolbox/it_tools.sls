{% from "toolbox/map.jinja" import toolbox with context %}
{% from "podman/macros.jinja" import container with context %}

{%- set c = toolbox.it_tools %}
{%- set spec = {
    'name': c.container_name,
    'image': c.image,
    'tag': c.tag,
    'ports': [c.host_port ~ ':' ~ c.container_port],
    'tmpfs': c.tmpfs,
    'cap_add': c.cap_add,
} %}
{%- do spec.update(c.podman) %}
{{ container('toolbox-it-tools-container', spec) }}
