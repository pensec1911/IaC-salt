# Pillar for formulas/orch. Everything has a working default (orch/map.jinja).
# Target this file at the master's minion AND its runner id (<host>_master)
# in pillar/top.sls — the orchestrate run compiles pillar for the latter.
orch:
  lookup:
    reboot:
      # Minions to check, and the flag file that marks a pending reboot.
      tgt: "*"
      tgt_type: glob         # e.g. compound: "* and not jellyfin"
      flag_file: /run/reboot-required
      # Rebooted first, in this order; other pending minions follow
      # alphabetically.
      order:
        - monitoring
        - homepage
      # Runs the salt-master: always last, not waited for.
      master_id: salt-master
      delay_minutes: 1       # system.reboot at_time
      query_timeout: 30      # s, flag query; silent minions are skipped
      boot_timeout: 600      # s, until salt/minion/<id>/start
      converge_timeout: 900  # s, queued highstate after boot
      timer:
        enabled: True        # False: run by hand only
        unit: orch-reboot
        sls: orch.reboot
        on_calendar: "*-*-* 03:15:00 Europe/Berlin"
        timeout: 40min
        salt_run: /usr/bin/salt-run
    rollout:
      # Which minions; only those answering test.ping take part.
      tgt: "*"
      tgt_type: glob         # e.g. list: "homepage,monitoring"
      # Applied first, in this order; the rest alphabetically.
      order:
        - monitoring
        - homepage
      # Applied last, not waited on (may restart salt-master).
      master_id: salt-master
      dry_run: True          # test=True highstate on all before the first apply
      query_timeout: 30      # s, test.ping
      apply_timeout: 900     # s, per highstate
