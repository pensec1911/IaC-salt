# Optional overrides for formulas/alloy/map.jinja. Nothing is required —
# the Loki address comes from the Salt Mine (formulas/loki).
alloy:
  lookup:
    tag: v1.20.1
    config_dir: /opt/alloy/config
    data_dir: /opt/alloy/data
    docker_socket: /var/run/docker.sock
    journal_path: /var/log/journal
    # How far back a fresh Alloy (no positions yet) reads the journal.
    journal_max_age: 12h
    # Push URL = http://<ip from this mine alias>:<loki_port>
    loki_mine_alias: loki
    loki_port: 3100
