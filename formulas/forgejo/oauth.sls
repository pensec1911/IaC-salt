{% from "forgejo/map.jinja" import forgejo with context %}

include:
  - forgejo.container

{#- OAuth2/OIDC login sources (forgejo admin auth add-oauth), created once —
   an existing source with that name is left alone (change it in the UI or
   with `forgejo admin auth update-oauth`). The client secret goes in via
   the environment (podman exec -e S), never on a command line or in the
   state output. #}
{%- for name, src in forgejo.oauth_sources | dictsort %}
{%-   set secret = src.get('secret') or '' %}{#- secret-scan: allow (pillar value from OpenBao) #}
{%-   if not secret or secret.startswith('sdb://') %}

forgejo-oauth-{{ name }}:
  test.fail_without_changes:
    - name: forgejo:lookup:oauth_sources:{{ name }}:secret empty or unresolved (OpenBao, README)
{%-   else %}
{%-     set args = ['--name', name, '--provider', src.get('provider', 'openidConnect'),
                    '--key', src.key, '--auto-discover-url', src.discovery_url] %}
{%-     for scope in src.get('scopes', ['openid', 'email', 'profile']) %}{% do args.extend(['--scopes', scope]) %}{% endfor %}
{%-     if src.get('group_claim') %}{% do args.extend(['--group-claim-name', src.group_claim]) %}{% endif %}
{%-     if src.get('admin_group') %}{% do args.extend(['--admin-group', src.admin_group]) %}{% endif %}
{%-     if src.get('skip_local_2fa') %}{% do args.append('--skip-local-2fa') %}{% endif %}

forgejo-oauth-{{ name }}:
  cmd.run:
    - name: >-
        {{ forgejo.podman_bin }} exec -e S {{ forgejo.container_name }}
        sh -c 'exec forgejo admin auth add-oauth --secret "$S" "$@"' sh
{%-     for a in args %} {{ a | yaml_encode }}{% endfor %}
    - unless: >-
        {{ forgejo.podman_bin }} exec {{ forgejo.container_name }} forgejo admin auth list
        | awk -F'\t' 'NR>1 {print $2}' | grep -qxF {{ name | yaml_encode }}
    {#- Before the install wizard there's no DB. #}
    - onlyif: grep -Eq '^INSTALL_LOCK *= *true' {{ forgejo.data_dir }}/custom/conf/app.ini
    - env:
      - S: {{ secret | yaml_encode }}
    - require:
      - service: forgejo-container
{%-   endif %}
{%- endfor %}

{%- if not forgejo.oauth_sources %}

forgejo-oauth-none:
  test.nop
{%- endif %}
