# Where jobs ping their Healthchecks check (formulas/healthchecks-ping,
# server: formulas/healthchecks on jellyfin, pillar/healthchecks.sls).
# The ping key is optional: until it is in OpenBao (created in the
# Healthchecks UI, formulas/healthchecks README) no job pings.
healthchecks_ping:
  lookup:
    base_url: "http://192.168.178.24:8000"
    ping_key: {{ (salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/project?ping_key') or '') | yaml_encode }}
