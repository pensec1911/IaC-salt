{% from "cadvisor/map.jinja" import cadvisor with context %}
{% from "podman/macros.jinja" import container with context %}

{#- Read-only host binds for the cgroup tree, filesystem and disk stats;
   see map.jinja for the raw-cgroup mode. #}
{%- set spec = {
    'name': cadvisor.container_name,
    'image': cadvisor.image,
    'tag': cadvisor.tag,
    'ports': [cadvisor.host_port ~ ':8080'],
    'volumes': [
        '/:/rootfs:ro',
        '/sys:/sys:ro',
        '/sys/fs/cgroup:/sys/fs/cgroup:ro',
        '/dev/disk:/dev/disk:ro',
        '/etc/machine-id:/etc/machine-id:ro',
    ],
    'podman_args': ['--cgroupns=host'],
    'command': [
        '--docker_only=true',
        '--raw_cgroup_prefix_whitelist=' ~ cadvisor.raw_cgroup_prefixes | join(','),
        '--housekeeping_interval=' ~ cadvisor.housekeeping_interval,
    ],
} %}
{%- do spec.update(cadvisor.podman) %}
{{ container('cadvisor-container', spec) }}
