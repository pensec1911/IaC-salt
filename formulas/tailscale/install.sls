{% from "tailscale/map.jinja" import tailscale with context %}
{%- set codename = grains['oscodename'] %}

tailscale-prereqs:
  pkg.installed:
    - pkgs:
      - curl

{#- The repo's key in binary form (*.noarmor.gpg), fetched once. #}
tailscale-repo-key:
  cmd.run:
    - name: curl -fsSL -o {{ tailscale.keyring }} {{ tailscale.repo_url }}/{{ codename }}.noarmor.gpg && chmod 644 {{ tailscale.keyring }}
    - unless: test -s {{ tailscale.keyring }}
    - require:
      - pkg: tailscale-prereqs

tailscale-repo:
  pkgrepo.managed:
    - name: deb [signed-by={{ tailscale.keyring }}] {{ tailscale.repo_url }} {{ codename }} main
    - file: /etc/apt/sources.list.d/tailscale.list
    - require:
      - cmd: tailscale-repo-key

tailscale-package:
  pkg.installed:
    - name: {{ tailscale.pkg }}
    - require:
      - pkgrepo: tailscale-repo

tailscale-service:
  service.running:
    - name: {{ tailscale.service }}
    - enable: True
    - require:
      - pkg: tailscale-package
