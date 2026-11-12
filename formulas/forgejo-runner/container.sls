{% from "forgejo-runner/map.jinja" import runner with context %}
{% from "podman/macros.jinja" import container, network with context %}

include:
  - forgejo-runner.config
{%- if runner.secret_valid %}
{{ network('forgejo-runner-network', runner.network) }}

{#- The one exception to formulas/podman's hardening: Docker-in-Docker needs
   a privileged container in the host user namespace (nested dockerd,
   cgroups, overlayfs, iptables). Jobs run inside it, not privileged (see
   map.jinja). Plain TCP without TLS: reachable only on the private
   network, where the runner is the only other member. #}
{%- set dind = {
    'name': runner.dind_container_name,
    'image': runner.dind_image,
    'tag': runner.dind_tag,
    'privileged': True,
    'userns': 'host',
    'no_new_privileges': False,
    'drop_caps': [],
    'read_only': False,
    'network': runner.network ~ '.network',
    'env': {'DOCKER_TLS_CERTDIR': ''},
    'volumes': [runner.dind_dir ~ ':/var/lib/docker:rw'],
    'command': ['dockerd', '-H', 'tcp://0.0.0.0:' ~ runner.dind_port, '--tls=false'],
} %}
{%- do dind.update(runner.dind_podman) %}
{{ container('forgejo-runner-dind-container', dind,
             require=[{'cmd': 'forgejo-runner-network-daemon-reload'},
                      {'file': 'forgejo-runner-network'},
                      {'file': 'forgejo-runner-dind-dir'}]) }}

{#- Runs as the forgejo-runner uid/gid, mapped 1:1: data_dir stays theirs. #}
{%- set dind_unit = runner.dind_container_name ~ '.service' %}
{%- set spec = {
    'name': runner.container_name,
    'image': runner.image,
    'tag': runner.tag,
    'user': runner.uid ~ ':' ~ runner.gid,
    'keep_uids': [runner.uid],
    'keep_gids': [runner.gid],
    'network': runner.network ~ '.network',
    'env': {'DOCKER_HOST': 'tcp://' ~ runner.dind_container_name ~ ':' ~ runner.dind_port},
    'volumes': [runner.data_dir ~ ':/data:rw'],
    'command': ['forgejo-runner', 'daemon', '--config', '/data/config.yml'],
    'unit': {'Requires': [dind_unit], 'After': [dind_unit]},
} %}
{%- do spec.update(runner.podman) %}
{{ container('forgejo-runner-container', spec,
             require=[{'user': 'user-forgejo-runner'}, {'service': 'forgejo-runner-dind-container'}],
             watch=[{'file': 'forgejo-runner-config'}, {'file': 'forgejo-runner-token'}]) }}
{%- endif %}
