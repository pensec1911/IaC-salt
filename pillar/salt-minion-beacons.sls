# Service beacon (formulas/salt-minion) for the minions listed under this
# file in pillar/top.sls — the docker hosts. A stopped docker is started
# again by the master's reactor (only services in
# salt-master:lookup:beacon_restart_services). Also on arrstack/jellyfin:
# service.start only, no highstate — nothing is recreated.
salt-minion:
  lookup:
    beacons:
      service:
        enabled: True
        services:
          - docker
