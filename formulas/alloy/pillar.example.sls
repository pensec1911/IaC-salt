# Optional overrides for formulas/alloy/map.jinja. Nothing is required —
# the Loki address comes from the Salt Mine (formulas/loki).
alloy:
  lookup:
    tag: v1.20.1
    config_dir: /opt/alloy/config
    data_dir: /opt/alloy/data
    journal_path: /var/log/journal
    # Host group that may read the journal; mapped 1:1 into the container.
    journal_group: systemd-journal
    # How far back a fresh Alloy (no positions yet) reads the journal.
    journal_max_age: 12h
    # Push URL = http://<ip from this mine alias>:<loki_port>
    loki_mine_alias: loki
    loki_port: 3100
