{#- formulas/openbao-snapshot on salt-master: nightly Raft snapshot of
   OpenBao (.20, not a minion) into /var/backups/openbao, which the
   master's own restic backup carries (pillar/backup.sls). #}
openbao_snapshot:
  lookup:
    addr: "https://192.168.178.20:8200"
    # AppRole `openbao-snapshot` (formulas/openbao-snapshot README "Bootstrap").
    role_id: "fc384c5a-7451-b94d-5e75-2e4d6d49a3a9"
