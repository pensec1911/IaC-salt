grafana:
  lookup:
    admin_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/grafana/admin?password') | yaml_encode }}
