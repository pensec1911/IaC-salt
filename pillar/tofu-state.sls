{#- formulas/tofu-state on forgejo: postgres for IaC-opentofu's state
   (backend "pg"). Password in OpenBao tofu-state/postgres (README). #}
tofu-state:
  lookup:
    db_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/tofu-state/postgres?password') | yaml_encode }}
