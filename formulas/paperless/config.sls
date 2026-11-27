{% from "paperless/map.jinja" import paperless with context %}

{#- name in /run/secrets -> value (pillar, i.e. OpenBao). A blank or
   unresolved one (an unresolved sdb reference reaches here as the URI)
   would start Paperless with a guessable key or an empty DB password —
   fail instead. #}
{%- set secrets = {} %}
{%- do secrets.update({'secret_key': paperless.secret_key}) %}
{%- do secrets.update({'db_password': paperless.db_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- set oidc = paperless.oidc %}
{%- if oidc.server_url %}
{%-   set app = {
          'provider_id': oidc.provider_id,
          'name': oidc.name,
          'client_id': oidc.client_id,
          'settings': {'server_url': oidc.server_url},
      } %}
{%-   do app.update({'secret': paperless.oidc_client_secret}) %}{#- secret-scan: allow (variable, not a value) #}
{%-   set provider = {'openid_connect': {'OAUTH_PKCE_ENABLED': True, 'APPS': [app]}} %}
{#-   `json` returns Markup, which yaml_encode can't represent — format()
      into a plain str. #}
{%-   do secrets.update({'socialaccount_providers': '%s' | format(provider | json)}) %}
{%- endif %}
{%- set bad = [] %}
{%- for name, value in [('secret_key', paperless.secret_key), ('db_password', paperless.db_password)] %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}
{%- if oidc.server_url and (not paperless.oidc_client_secret or paperless.oidc_client_secret.startswith('sdb://')) %}
{%-   do bad.append('oidc_client_secret') %}
{%- endif %}
{%- if not paperless.url %}{% do bad.append('url') %}{% endif %}

paperless-config-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "paperless:lookup empty or unresolved: {{ bad | join(', ') }} — secrets in OpenBao paperless/app (README)"
{%- else %}
  test.succeed_without_changes:
    - name: paperless:lookup is complete
{%- endif %}

paperless-base-dir:
  file.directory:
    - name: {{ paperless.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- The container runs as uid/gid (1:1 mapped): it owns its data dir. #}
paperless-data-dir:
  file.directory:
    - name: {{ paperless.data_dir }}
    - user: {{ paperless.uid }}
    - group: {{ paperless.gid }}
    - mode: '0750'
    - require:
      - file: paperless-base-dir
      - user: user-paperless

{#- Owner left to the containers (:U, container.sls): only create. #}
{%- for name, dir in [('postgres', paperless.postgres_dir), ('valkey', paperless.valkey_dir)] %}

paperless-{{ name }}-dir:
  file.directory:
    - name: {{ dir }}
    - require:
      - file: paperless-base-dir
{%- endfor %}

paperless-dump-dir:
  file.directory:
    - name: {{ paperless.dump_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: paperless-base-dir

{#- media + consume. On the NFS share (nfs_mount set) created as uid/gid
   directly: the NAS squashes root, so root can't create anything there
   (formulas/arrstack does the same). setpriv because the account has a
   nologin shell. Locally a plain file.directory. #}
{%- for name, dir in [('media', paperless.media_dir), ('consume', paperless.consume_dir)] %}

paperless-{{ name }}-dir:
{%-   if paperless.nfs_mount %}
  cmd.run:
    - name: setpriv --reuid={{ paperless.uid }} --regid={{ paperless.gid }} --clear-groups install -d -m 0750 {{ dir }}
    - creates: {{ dir }}
    - require:
      - user: user-paperless
      - mount: nfs-mount-{{ paperless.nfs_mount }}
{%-   else %}
  file.directory:
    - name: {{ dir }}
    - user: {{ paperless.uid }}
    - group: {{ paperless.gid }}
    - mode: '0750'
    - makedirs: True
    - require:
      - user: user-paperless
{%-   endif %}
{%- endfor %}

{#- Files bound one by one, 0444: postgres runs as a sub-UID. The 0700 dir
   keeps host users out. No trailing newline — PAPERLESS_<X>_FILE takes the
   file content as is. #}
paperless-secrets-dir:
  file.directory:
    - name: {{ paperless.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: paperless-base-dir
{%- for name, value in secrets | dictsort %}

paperless-secret-{{ name }}:
  file.managed:
    - name: {{ paperless.secrets_dir }}/{{ name }}
    - contents: {{ value | yaml_encode }}
    - contents_newline: False
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False   # secret — keep it out of state output / job cache
    - require:
      - file: paperless-secrets-dir
      - test: paperless-config-valid
{%- endfor %}
