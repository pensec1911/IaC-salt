# Salt version of every host (formulas/salt-minion version.sls: exact apt pin;
# upgrade via orch.salt-upgrade, formulas/orch). Targeted at '*' in
# pillar/top.sls — that includes salt-master_master, the orchestrate run's
# own id, which reads target from here.
#
# Bump: Renovate PR (deb datasource, 3008 LTS line) -> merge -> push, then on
# the master `salt-run state.orchestrate orch.salt-upgrade` twice: the first
# run upgrades salt-master, the second (once it's back) the minions, one at a
# time. Until the master runs the target, the other hosts stay capped at
# master_running.
salt-minion:
  lookup:
    version:
      target: "3008.3"
      # Exempt from the cap: the host the salt-master runs on.
      master_id: salt-master
      # Runs inside the salt-master rendering this pillar -> its own version.
      master_running: {{ salt['test.version']() | yaml_encode }}
