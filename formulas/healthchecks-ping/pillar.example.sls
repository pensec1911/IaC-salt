# Real data goes in pillar/healthchecks-ping.sls (every minion, pillar/top.sls).
healthchecks_ping:
  lookup:
    base_url: "http://192.168.178.24:8000"
    # Project ping key — OpenBao only. Optional: empty/unresolved = no pings.
    ping_key: {{ (salt['sdb.get']('sdb://osvault/homelab/data/healthchecks/project?ping_key') or '') | yaml_encode }}
    # curl: per-try timeout, delay between tries, total retry budget (s).
    max_time: 10
    retry_delay: 15
    retry_max_time: 300
