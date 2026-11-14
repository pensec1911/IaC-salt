{#- Exporters for Proxmox, FRITZ!Box and TrueNAS on monitoring
   (formulas/infra-exporters). pve and fritzbox are only enabled once their
   secret resolves from OpenBao — before that nothing changes on monitoring.
   pillar/prometheus.sls uses the same two checks for its scrape jobs and
   rules; keep them in step. #}
{%- set pve_token = salt['sdb.get']('sdb://osvault/homelab/data/proxmox/exporter?token_value') or '' %}
{%- set pve = pve_token is string and pve_token | length > 0 and not pve_token.startswith('sdb://') %}
{%- set fritz_password = salt['sdb.get']('sdb://osvault/homelab/data/fritzbox/exporter?password') or '' %}
{%- set fritzbox = fritz_password is string and fritz_password | length > 0 and not fritz_password.startswith('sdb://') %}
infra-exporters:
  lookup:
{%- if pve %}
    # PVE user + API token (PVEAuditor, privsep off) — formulas/infra-exporters README.
    pve:
      enabled: True
      user: prometheus@pve
      token_name: exporter
      token_value: {{ pve_token | yaml_encode }}
{%- endif %}
{%- if fritzbox %}
    # FRITZ!Box user with only "FRITZ!Box settings" — README.
    fritzbox:
      enabled: True
      name: fritzbox
      hostname: 192.168.178.1
      username: prometheus
      password: {{ fritz_password | yaml_encode }}
{%- endif %}
    # TrueNAS pushes Graphite to monitoring:9109 (Reporting → Exporters, README).
    truenas:
      enabled: True
