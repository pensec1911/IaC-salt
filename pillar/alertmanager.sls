{#- Notifications go to ntfy on jellyfin (formulas/ntfy), one topic per
   severity, rendered by ntfy's built-in Alertmanager template. Guarded: only
   when the publisher token resolves from OpenBao — otherwise everything stays
   on the "null" receiver (UI on :9093 and Grafana only), as before, so a
   missing secret never breaks the self-repairing Alertmanager.
   Alerts that point at a broken minion are also posted to salt-api on the
   master, which runs that minion's drift check right away
   (formulas/salt-master README "salt-api") — it repairs where self-repair is
   allowed now, else only reports, same as the hourly run. #}
{%- set ntfy_url = 'http://192.168.178.24:8090' %}
{%- set ntfy_token = salt['sdb.get']('sdb://osvault/homelab/data/ntfy/alertmanager?token') or '' %}
{%- set ntfy = ntfy_token is string and ntfy_token.startswith('tk_') %}
alertmanager:
  config:
    route:
      receiver: "null"
      group_by: [alertname, instance]
      routes:
        # continue: the ntfy routes below still get these too.
        - receiver: salt-api
          continue: true
          matchers:
            - alertname=~"TargetDown|ProbeFailed"
          group_wait: 30s
          group_interval: 5m
          # Still firing an hour later: try again (the check is idempotent).
          repeat_interval: 1h
{%- if ntfy %}
        # group_by alertname: a burst (one alert on several hosts) is one
        # push; the message lists every instance.
        - receiver: ntfy-critical
          matchers:
            - severity="critical"
          group_by: [alertname]
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 4h
        # Everything else, alerts without a severity label included.
        - receiver: ntfy-warning
          group_by: [alertname]
          group_wait: 2m
          group_interval: 10m
          repeat_interval: 24h
{%- endif %}
    receivers:
      - name: "null"
      - name: salt-api
        webhook_configs:
          - url: https://192.168.178.28:8000/hook/alertmanager
            send_resolved: false
            http_config:
              authorization:
                type: Bearer
                credentials: {{ salt['sdb.get']('sdb://osvault/homelab/data/salt-api/alertmanager?token') | yaml_encode }}
              # salt-api's self-signed cert (/etc/salt/pki/api/salt-api.crt
              # on the master, SAN IP 192.168.178.28, expires 2031-10-25).
              # Public data. Re-issued: paste the new one here and in
              # pillar/forgejo.sls (extra_ca_certs).
              tls_config:
                ca: |
                  -----BEGIN CERTIFICATE-----
                  MIIBsDCCAVagAwIBAgIUaSoGYkucZnJssbEDf/GQcCEFCM4wCgYIKoZIzj0EAwIw
                  JTEQMA4GA1UECgwHaG9tZWxhYjERMA8GA1UEAwwIc2FsdC1hcGkwHhcNMjYxMDI2
                  MTI0MTE0WhcNMzExMDI1MTI0MTE0WjAlMRAwDgYDVQQKDAdob21lbGFiMREwDwYD
                  VQQDDAhzYWx0LWFwaTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABEhiYHcdChtl
                  CFUnk9UR0BmLEn2ZBtNlXky1wZRuiq4zE+W770w6lnlpy8J2SsEPZMwZ7k8jzuMQ
                  sk8/z2+K9bujZDBiMB0GA1UdDgQWBBRtKiKSuJBgjpCp/2+OncHETVnOvzAfBgNV
                  HSMEGDAWgBRtKiKSuJBgjpCp/2+OncHETVnOvzAPBgNVHREECDAGhwTAqLIcMA8G
                  A1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIhAPYFoMyEuLMYHXushxT6
                  W7CoeJ9ETeaO2h0cQeXqXn0DAiAyW8FoTWHOeKjOKx4sfijvJalZtsa5VXBNnx+Q
                  iIUfNg==
                  -----END CERTIFICATE-----
{%- if ntfy %}
{%-   for severity, priority in [('critical', 'high'), ('warning', 'default')] %}
      # Bearer credential of ntfy user "alertmanager", write-only on alerts-* (pillar/ntfy.sls).
      - name: ntfy-{{ severity }}
        webhook_configs:
          - url: {{ (ntfy_url ~ '/alerts-' ~ severity ~ '?template=alertmanager&priority=' ~ priority) | yaml_encode }}
            send_resolved: true
            http_config:
              authorization:
                type: Bearer
                credentials: {{ ntfy_token | yaml_encode }}
{%-   endfor %}
{%- endif %}
