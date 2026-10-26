{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. Fired by the master itself after every gitfs
   fetch (fileserver_events); `changed` is true only when new commits
   arrived, i.e. after a push. Then the push orchestrate run
   (homelab_push_orch_sls, formulas/orch orch.push) deploys it.

   Fired by the master's own maintenance process — no minion or webhook
   can send it. #}
{%- if data.get('changed') is sameas true %}
deploy-push:
  runner.state.orchestrate:
    - args:
      - mods: {{ opts.get('homelab_push_orch_sls', 'orch.push') | yaml_encode }}
{%- endif %}
