users:
  accounts:
    # Pinned uid/gid — the container runs as it (Podman User=, mapped 1:1).
    # Must match ntfy:lookup:uid/gid below.
    - name: ntfy
      system: true
      shell: /usr/sbin/nologin
      home: /var/lib/ntfy
      uid: 974
      gid: 974

{#- Healthchecks (formulas/healthchecks, same VM) publishes missed
   heartbeats with its own user, write-only on alerts-critical — listed
   only once its token is in OpenBao, so ntfy keeps working before that. #}
{%- set hc_token = salt['sdb.get']('sdb://osvault/homelab/data/ntfy/healthchecks?token') or '' %}
{%- set hc_publisher = hc_token is string and hc_token.startswith('tk_') %}
# Push notifications for Alertmanager (pillar/alertmanager.sls), LAN only.
# Topics alerts-critical / alerts-warning; the alertmanager user may only
# publish to alerts-*, everyone else is denied. Phone: ntfy app, server
# below, log in as admin (OpenBao ntfy/admin), subscribe to both topics.
ntfy:
  lookup:
    uid: 974
    gid: 974
    base_url: "http://192.168.178.24:8090"
    admin_password_hash: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/admin?password_hash') | yaml_encode }}
    publisher_password_hash: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/alertmanager?password_hash') | yaml_encode }}
    publisher_token: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/alertmanager?token') | yaml_encode }}
{%- if hc_publisher %}
    extra_publishers:
      - user: healthchecks
        password_hash: {{ salt['sdb.get']('sdb://osvault/homelab/data/ntfy/healthchecks?password_hash') | yaml_encode }}
        token: {{ hc_token | yaml_encode }}
        topics:
          - alerts-critical
{%- endif %}
