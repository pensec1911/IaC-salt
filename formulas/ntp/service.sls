{% from "ntp/map.jinja" import ntp with context %}

ntp-service:
  service.running:
    - name: {{ ntp.service }}
    - enable: True
    - watch:
      - file: ntp-timesyncd-dropin
