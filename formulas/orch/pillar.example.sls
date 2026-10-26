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
