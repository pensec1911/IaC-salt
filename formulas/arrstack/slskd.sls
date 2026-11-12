{% from "arrstack/map.jinja" import arrstack with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - arrstack.gluetun

{#- slskd doesn't support PUID/PGID (that's an LSIO-image convention, and
   this isn't an LSIO image) — runs as the pinned media uid:gid directly
   (User=), mapped 1:1, same approach as formulas/grafana and
   formulas/prometheus. Names as slskd itself lists them (`slskd --envars`).
   Unknown SLSKD_* vars are ignored silently, so a typo here falls back to
   the default web login slskd/slskd and leaves Soulseek disconnected.
   Credentials go through the 0600 secret env file.
   DOTNET_BUNDLE_EXTRACT_BASE_DIR: slskd is a .NET single-file bundle that
   unpacks itself on start — default $HOME/.net, which the read-only root
   refuses (EROFS); /tmp is a tmpfs. #}
{%- set spec = {
    'name': arrstack.slskd.container_name,
    'image': arrstack.slskd.image,
    'tag': arrstack.slskd.tag,
    'user': arrstack.puid ~ ':' ~ arrstack.pgid,
    'keep_uids': [arrstack.puid],
    'keep_gids': [arrstack.pgid],
    'env': {
        'SLSKD_SLSK_LISTEN_PORT': arrstack.slskd.soulseek_port,
        'SLSKD_DOWNLOADS_DIR': '/media/incomplete',
        'SLSKD_INCOMPLETE_DIR': '/media/incomplete',
        'DOTNET_BUNDLE_EXTRACT_BASE_DIR': '/tmp',
    },
    'secret_env': {},
    'volumes': [
        arrstack.config_base ~ '/slskd:/app:rw',
        arrstack.media_mount ~ ':/media:rw',
    ],
} %}
{%- do spec.secret_env.update({'SLSKD_USERNAME': arrstack.slskd.web_username}) %}
{%- do spec.secret_env.update({'SLSKD_PASSWORD': arrstack.slskd.web_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.secret_env.update({'SLSKD_SLSK_USERNAME': arrstack.slskd.soulseek_username}) %}
{%- do spec.secret_env.update({'SLSKD_SLSK_PASSWORD': arrstack.slskd.soulseek_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.update(arrstack.attach) %}
{%- do spec.update(arrstack.slskd.podman) %}
{{ container('slskd-container', spec,
             require=[{'user': 'user-media'}, {'file': 'arrstack-slskd-config-dir'},
                      {'cmd': 'arrstack-incomplete-dir'}, {'mount': 'nfs-mount-media'}]) }}
