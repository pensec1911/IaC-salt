# formulas/orch — targeted at salt-master (timer) and salt-master_master (the
# orchestrate run's own pillar id) in pillar/top.sls.
orch:
  lookup:
    reboot:
      # monitoring first, so it watches the rest come back; the media hosts
      # last. The 03:15 Berlin timer keeps the whole run inside the 03:00–06:00
      # window of arrstack/jellyfin and before the Sunday 04:00 restore test.
      order:
        - monitoring
        - homepage
        - wazuh
        - arrstack
        - jellyfin
      master_id: salt-master
