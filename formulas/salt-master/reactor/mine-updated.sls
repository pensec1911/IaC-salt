{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. Fired by a minion whose mine conf changed
   (formulas/node-exporter, formulas/cadvisor), after its mine.update — so
   the consumers' highstate already sees the new entry.

   Consumers come from master opts (reactor.conf), not from the event: a
   minion can only ask for "refresh", never pick what gets applied.
   queue=True: if the sender *is* a consumer (fresh monitoring), its own run
   still holds the lock; this one runs right after and picks up itself. #}
{%- set consumers = opts.get('homelab_mine_consumers', []) %}
{%- if consumers %}
highstate-mine-consumers:
  local.state.apply:
    - tgt: {{ consumers | join(',') | yaml_encode }}
    - tgt_type: list
    - kwarg:
        queue: True
{%- endif %}
