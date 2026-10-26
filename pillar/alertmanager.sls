# No notification channel yet: everything goes to the "null" receiver (UI on
# :9093 and Grafana only). Alerts that point at a broken minion are also
# posted to salt-api on the master, which runs that minion's drift check
# right away (formulas/salt-master README "salt-api") — it repairs where
# self-repair is allowed now, else only reports, same as the hourly run.
alertmanager:
  config:
    route:
      receiver: "null"
      group_by: [alertname, instance]
      routes:
        # continue: a real receiver added later still gets these too.
        - receiver: salt-api
          continue: true
          matchers:
            - alertname=~"TargetDown|ProbeFailed"
          group_wait: 30s
          group_interval: 5m
          # Still firing an hour later: try again (the check is idempotent).
          repeat_interval: 1h
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
