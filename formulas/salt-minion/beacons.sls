{% from "salt-minion/map.jinja" import salt_minion with context %}
{%- set svc = salt_minion.beacons.service %}

{%- if svc.enabled and svc.services %}

# save: persisted to /etc/salt/minion.d/beacons.conf, survives restarts.
salt-minion-beacon-service:
  beacon.present:
    - name: service
    - save: True
    - services:
        {%- for name in svc.services %}
        {{ name }}:
          onchangeonly: True
          emitatstartup: False
          delay: {{ svc.delay_seconds }}
        {%- endfor %}
    - interval: {{ svc.interval_seconds }}

{%- else %}

salt-minion-beacon-service:
  beacon.absent:
    - name: service
    - save: True

{%- endif %}
