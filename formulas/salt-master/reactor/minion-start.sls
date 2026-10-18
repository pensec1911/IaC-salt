{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. `data` is the salt/minion/<id>/start event; the
   master has already checked that `id` is the authenticated sender.

   Full highstate, not a single formula: requisites cross formulas (users,
   docker, nfs-mount). queue=True: if the minion's drift check or another
   run holds the state lock, this waits instead of being dropped. #}
highstate-on-start:
  local.state.apply:
    - tgt: {{ data['id'] | yaml_encode }}
    - kwarg:
        queue: True
