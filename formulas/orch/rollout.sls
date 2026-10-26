{#- Orchestrate SLS (not a state for a minion) — run on the master, by hand:
     salt-run state.orchestrate orch.rollout            # dry run on all, then apply in order
     salt-run state.orchestrate orch.rollout test=True  # touches nothing
   The run itself: orch/rollout.jinja. Knobs: orch/map.jinja. #}
{%- from "orch/map.jinja" import orch with context %}
{%- from "orch/rollout.jinja" import rollout with context %}
{{ rollout(orch.rollout) }}
