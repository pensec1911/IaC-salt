# Real data goes in pillar/openbao-snapshot.sls (salt-master only, pillar/top.sls).
openbao_snapshot:
  lookup:
    addr: "https://192.168.178.20:8200"
    # AppRole `openbao-snapshot` (README "Bootstrap") — role_id isn't secret.
    role_id: "00000000-0000-0000-0000-000000000000"
    # Defaults (map.jinja): ca_file, secret_id_file, target_dir, on_calendar …
    # target_dir must be in this minion's paths in pillar/backup.sls.
