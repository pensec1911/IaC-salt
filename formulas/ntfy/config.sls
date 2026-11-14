{% from "ntfy/map.jinja" import ntfy with context %}

{#- A blank or unresolved secret would make ntfy refuse the config or
   provision a user without a usable password — fail instead (an unresolved
   sdb reference reaches here as the URI). #}
{%- set secrets = {} %}
{%- do secrets.update({'admin_password_hash': ntfy.admin_password_hash}) %}
{%- do secrets.update({'publisher_password_hash': ntfy.publisher_password_hash}) %}
{%- do secrets.update({'publisher_token': ntfy.publisher_token}) %}{#- secret-scan: allow (variable, not a value) #}
{%- for p in ntfy.extra_publishers %}
{%-   do secrets.update({'extra_publishers[' ~ p.user ~ '].password_hash': p.password_hash}) %}
{%-   do secrets.update({'extra_publishers[' ~ p.user ~ '].token': p.token}) %}{#- secret-scan: allow (variable, not a value) #}
{%- endfor %}
{%- set bad = [] %}
{%- for name, value in secrets | dictsort %}
{%-   if not value or value.startswith('sdb://') %}{% do bad.append(name) %}{% endif %}
{%- endfor %}

ntfy-secrets-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "ntfy:lookup secrets empty or unresolved: {{ bad | join(', ') }} — set them in OpenBao ntfy/<user> (README)"
{%- else %}
  test.succeed_without_changes:
    - name: ntfy:lookup secrets are set
{%- endif %}

ntfy-base-dir:
  file.directory:
    - name: {{ ntfy.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- server.yml holds the password hashes and the publisher's API key, so it is root-owned,
   readable by the ntfy group only (gid mapped 1:1 into the container). #}
ntfy-config-dir:
  file.directory:
    - name: {{ ntfy.config_dir }}
    - user: root
    - group: {{ ntfy.gid }}
    - mode: '0750'
    - require:
      - file: ntfy-base-dir
      - user: user-ntfy

{#- auth.db (users, ACLs, tokens) and cache.db (message buffer). #}
ntfy-data-dir:
  file.directory:
    - name: {{ ntfy.data_dir }}
    - user: {{ ntfy.uid }}
    - group: {{ ntfy.gid }}
    - mode: '0750'
    - require:
      - file: ntfy-base-dir
      - user: user-ntfy

{#- Values are read from pillar inside the template, not passed as state
   args — those end up in the master's job cache. #}
ntfy-server.yml:
  file.managed:
    - name: {{ ntfy.config_dir }}/server.yml
    - source: salt://ntfy/files/server.yml.j2
    - template: jinja
    - user: root
    - group: {{ ntfy.gid }}
    - mode: '0640'
    - show_changes: False
    - require:
      - test: ntfy-secrets-valid
      - file: ntfy-config-dir
