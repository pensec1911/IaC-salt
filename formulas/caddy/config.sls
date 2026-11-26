{% from "caddy/map.jinja" import caddy with context %}

{#- Without the Porkbun keys Caddy can't get its certificate (an unresolved
   sdb reference reaches here as the URI); without a domain there is no
   site — fail instead. #}
{%- set bad = [] %}
{%- for key in ['porkbun_api_key', 'porkbun_secret_api_key'] %}
{%-   if not caddy[key] or caddy[key].startswith('sdb://') %}{% do bad.append(key) %}{% endif %}
{%- endfor %}
{%- if not caddy.domain %}{% do bad.append('domain') %}{% endif %}
{#- Fail closed: a route that wants forward auth without an auth server
   would be served open. #}
{%- if not caddy.forward_auth and caddy.routes | selectattr('auth', 'equalto', 'forward') | list %}
{%-   do bad.append('forward_auth (routes with auth: forward)') %}
{%- endif %}

caddy-config-valid:
{%- if bad %}
  test.fail_without_changes:
    - name: "caddy:lookup empty or unresolved: {{ bad | join(', ') }} — keys from OpenBao porkbun/api (README)"
{%- else %}
  test.succeed_without_changes:
    - name: caddy:lookup is complete
{%- endif %}

caddy-base-dir:
  file.directory:
    - name: {{ caddy.base_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- Caddyfile: root-owned, world-readable (no secrets — those come in via
   env), mounted read-only. #}
caddy-config-dir:
  file.directory:
    - name: {{ caddy.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - require:
      - file: caddy-base-dir

{#- Certificates, ACME account key (/data) and Caddy's autosaved config
   (/config). #}
{%- for dir in ['data_dir', 'state_dir'] %}

caddy-{{ dir | replace('_', '-') }}:
  file.directory:
    - name: {{ caddy[dir] }}
    - user: {{ caddy.uid }}
    - group: {{ caddy.gid }}
    - mode: '0700'
    - require:
      - file: caddy-base-dir
      - user: user-caddy
{%- endfor %}

caddy-caddyfile:
  file.managed:
    - name: {{ caddy.config_dir }}/Caddyfile
    - source: salt://caddy/files/Caddyfile.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - test: caddy-config-valid
      - file: caddy-config-dir
