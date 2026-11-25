{% from "headscale/map.jinja" import headscale with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - headscale.config

{#- Runs as the headscale account (mapped 1:1); everything it writes is in
   /var/lib/headscale (the CLI socket too, config.yaml.j2), so the default
   read-only root fits. 8443 inside, so no capability for :443. #}
{%- set spec = {
    'name': headscale.container_name,
    'image': headscale.image,
    'tag': headscale.tag,
    'user': headscale.uid ~ ':' ~ headscale.gid,
    'keep_uids': [headscale.uid],
    'keep_gids': [headscale.gid],
    'ports': [
        headscale.https_port ~ ':8443/tcp',
        headscale.stun_port ~ ':3478/udp',
        headscale.metrics_host_ip ~ ':' ~ headscale.metrics_port ~ ':9090/tcp',
    ],
    'volumes': [
        headscale.config_dir ~ ':/etc/headscale:ro',
        headscale.data_dir ~ ':/var/lib/headscale:rw',
    ],
    'command': ['serve'],
} %}
{%- do spec.update(headscale.podman) %}
{{ container('headscale-container', spec,
             require=[{'user': 'user-headscale'}, {'file': 'headscale-data-dir'},
                      {'file': 'headscale-config.yaml'}, {'file': 'headscale-policy'},
                      {'file': 'headscale-extra-records'}],
             watch=[{'file': 'headscale-config.yaml'}, {'file': 'headscale-policy'}]) }}
