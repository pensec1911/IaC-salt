{% from "tailscale/map.jinja" import tailscale with context %}

include:
  - tailscale.install

{%- if tailscale.join %}
{%- set running = "tailscale status --json 2>/dev/null | grep -q '\"BackendState\": \"Running\"'" %}

{#- Only written while not logged in; the key is single-use anyway. #}
tailscale-authkey:
  file.managed:
    - name: {{ tailscale.authkey_file }}
    - contents_pillar: tailscale:lookup:auth_key
    - user: root
    - group: root
    - mode: '0600'
    - makedirs: True
    - show_changes: False
    - unless: {{ running | json }}
    - require:
      - service: tailscale-service

tailscale-up:
  cmd.run:
    - name: >-
        tailscale up --reset
        --login-server={{ tailscale.login_server }}
        --auth-key=file:{{ tailscale.authkey_file }}
        --hostname={{ tailscale.hostname }}
        --advertise-routes={{ tailscale.advertise_routes | join(',') }}
{%- if tailscale.advertise_tags %}
        --advertise-tags={{ tailscale.advertise_tags | join(',') }}
{%- endif %}
        --accept-dns={{ 'true' if tailscale.accept_dns else 'false' }}
        --snat-subnet-routes={{ 'true' if tailscale.snat_subnet_routes else 'false' }}
        --timeout=60s
    - unless: {{ running | json }}
    - require:
      - file: tailscale-authkey

tailscale-authkey-cleanup:
  file.absent:
    - name: {{ tailscale.authkey_file }}
    - require:
      - cmd: tailscale-up
{%- else %}

tailscale-not-joined:
  test.succeed_without_changes:
    - name: "tailscale: no login_server/auth_key in pillar — installed, not joined (README)"
{%- endif %}
