{% from "forgejo/map.jinja" import forgejo with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - forgejo.config

{#- Rootless image: web on 3000 and Forgejo's built-in SSH server on 2222
   inside the container (image defaults), so host port 22 stays with the
   VM's own sshd. Runs as the git uid/gid, mapped 1:1: data_dir stays theirs
   on the host. #}
{%- set env = {
    'TZ': forgejo.timezone,
    'FORGEJO__server__SSH_PORT': forgejo.ssh_port,
} %}
{%- if forgejo.extra_ca_certs %}
{%-   do env.update({'SSL_CERT_DIR': '/etc/ssl/certs:/etc/ssl/forgejo-ca'}) %}
{%- endif %}
{%- for section, keys in forgejo.app_ini | dictsort %}
{%-   for key, value in keys | dictsort %}
{%-     do env.update({'FORGEJO__' ~ section ~ '__' ~ key: value}) %}
{%-   endfor %}
{%- endfor %}
{%- set volumes = [forgejo.data_dir ~ ':/var/lib/gitea:rw'] %}
{%- if forgejo.extra_ca_certs %}
{%-   do volumes.append(forgejo.ca_dir ~ ':/etc/ssl/forgejo-ca:ro') %}
{%- endif %}
{%- set spec = {
    'name': forgejo.container_name,
    'image': forgejo.image,
    'tag': forgejo.tag,
    'user': forgejo.uid ~ ':' ~ forgejo.gid,
    'keep_uids': [forgejo.uid],
    'keep_gids': [forgejo.gid],
    'ports': [forgejo.http_port ~ ':3000', forgejo.ssh_port ~ ':2222'],
    'env': env,
    'volumes': volumes,
} %}
{%- do spec.update(forgejo.podman) %}
{{ container('forgejo-container', spec,
             require=[{'user': 'user-git'}, {'file': 'forgejo-data-dir'}]) }}
