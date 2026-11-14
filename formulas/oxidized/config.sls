{% from "oxidized/map.jinja" import oxidized with context %}
{%- if oxidized.enabled %}

{#- Enabled with a blank or unresolved key, a non-PEM Forgejo key or no
   device would only crash-loop or never push — fail instead (an unresolved
   sdb reference reaches here as the URI). pillar/oxidized.jinja enables it
   only once everything resolves, so this is the backstop. Values also must
   not contain a tab or newline: router.db is tab-separated. #}
{%- set bad = [] %}
{%- if not oxidized.remote_repo %}{% do bad.append('remote_repo empty') %}{% endif %}
{%- set fkey = oxidized.forgejo_key or '' %}
{%- if not fkey or fkey.startswith('sdb://') %}
{%-   do bad.append('forgejo_key empty or unresolved') %}
{%- elif 'BEGIN RSA PRIVATE' not in fkey %}
{%-   do bad.append('forgejo_key is not legacy PEM RSA (ssh-keygen -m PEM -t rsa)') %}
{%- endif %}
{%- set fpub = oxidized.forgejo_key_pub or '' %}
{%- if not fpub or fpub.startswith('sdb://') %}{% do bad.append('forgejo_key_pub empty or unresolved') %}{% endif %}
{%- if not oxidized.devices %}{% do bad.append('no devices') %}{% endif %}
{%- for name, d in oxidized.devices | dictsort %}
{%-   set dkey = d.get('ssh_key') or '' %}
{%-   if not dkey or dkey.startswith('sdb://') %}{% do bad.append(name ~ ': ssh_key empty or unresolved') %}{% endif %}
{%-   if not d.get('host') or not d.get('model') or not d.get('username') %}{% do bad.append(name ~ ': host/model/username missing') %}{% endif %}
{%-   if oxidized.input_secure and not (d.get('host_key') or {}).get('key') %}{% do bad.append(name ~ ': host_key missing') %}{% endif %}
{%-   for v in [name, d.get('host') | string, d.get('model') | string, d.get('username') | string] %}
{%-     if '\t' in v or '\n' in v %}{% do bad.append(name ~ ': tab/newline in a router.db field') %}{% endif %}
{%-   endfor %}
{%- endfor %}

oxidized-config-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "oxidized:lookup incomplete: {{ bad | join('; ') }} — see formulas/oxidized README"
{%- else %}
  test.succeed_without_changes:
    - name: oxidized:lookup is complete
{%- endif %}

oxidized-base-dir:
  file.directory:
    - name: {{ oxidized.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Read-only for the container through the "other" bits; nothing secret
   in here (router.db holds key paths, not keys). #}
oxidized-config-dir:
  file.directory:
    - name: {{ oxidized.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: oxidized-base-dir

oxidized-ssh-dir:
  file.directory:
    - name: {{ oxidized.config_dir }}/.ssh
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: oxidized-config-dir

{#- 0700 root: no host user gets in; the container sees each key through
   its own bind (0444, podman README "Read-only config from Salt"). #}
oxidized-secrets-dir:
  file.directory:
    - name: {{ oxidized.secrets_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - require:
      - file: oxidized-base-dir

{#- Owner left to the container (:U, container.sls): only create. #}
oxidized-data-dir:
  file.directory:
    - name: {{ oxidized.data_dir }}
    - require:
      - file: oxidized-base-dir

oxidized-config:
  file.managed:
    - name: {{ oxidized.config_dir }}/config
    - source: salt://oxidized/files/config.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: oxidized-config-dir

oxidized-router-db:
  file.managed:
    - name: {{ oxidized.config_dir }}/router.db
    - source: salt://oxidized/files/router.db.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: oxidized-config-dir

oxidized-known-hosts:
  file.managed:
    - name: {{ oxidized.config_dir }}/.ssh/known_hosts
    - source: salt://oxidized/files/known_hosts.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: oxidized-ssh-dir

{#- Key files: name in the container = file name here. #}
{%- set keys = {
    'forgejo': oxidized.forgejo_key,
    'forgejo.pub': oxidized.forgejo_key_pub,
} %}
{%- for name, d in oxidized.devices | dictsort %}
{%-   do keys.update({'device-' ~ name: d.ssh_key}) %}
{%- endfor %}
{%- for file, value in keys | dictsort %}

oxidized-key-{{ file }}:
  file.managed:
    - name: {{ oxidized.secrets_dir }}/{{ file }}
    - user: root
    - group: root
    - mode: '0444'
    - show_changes: False
    - contents: {{ (((value or '') | string).rstrip('\n') ~ '\n') | yaml_encode }}
    - require:
      - file: oxidized-secrets-dir
      - test: oxidized-config-valid
{%- endfor %}
{%- endif %}
