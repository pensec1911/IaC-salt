# Real values: pillar/infra-exporters.sls (monitoring). Defaults: map.jinja.
# pve and fritzbox stay off until enabled; enable them only together with
# a resolved secret (see pillar/infra-exporters.sls for the guard).

infra-exporters:
  lookup:
    pve:
      enabled: True
      user: prometheus@pve
      token_name: exporter
      token_value: {{ salt['sdb.get']('sdb://osvault/homelab/data/proxmox/exporter?token_value') | yaml_encode }}
      verify_ssl: False
      host_port: 9221
      tag: 3.11.0
    fritzbox:
      enabled: True
      name: fritzbox
      hostname: 192.168.178.1
      username: prometheus
      password: {{ salt['sdb.get']('sdb://osvault/homelab/data/fritzbox/exporter?password') | yaml_encode }}
      host_port: 9787
    truenas:
      enabled: True
      host_port: 9108
      graphite_port: 9109
      sample_expiry: 5m
      # Any podman container spec key (formulas/podman README), merged last.
      podman: {}
