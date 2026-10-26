{#- Orchestrate SLS (not a state for a minion) — started by formulas/salt-master's
   reactor when gitfs fetched new commits (a push), not by hand. orch.rollout
   with push's overrides on top (orch/map.jinja), so by default only the
   minions that may self-repair right now: arrstack/jellyfin by day are left
   to their nightly enforce window, wazuh (no enforce) to a manual apply.

   git_pillar polls on its own, so the pillar may still be a commit behind
   the states — it is fetched first. Rendered when the run starts: the
   ping and enforce-check queries run before that fetch, which is fine. #}
{%- from "orch/map.jinja" import orch with context %}
{%- from "orch/rollout.jinja" import rollout with context %}
{%- set r = orch.rollout.copy() %}
{%- do r.update(orch.push) %}

git-pillar-update:
  salt.runner:
    - name: git_pillar.update

{{ rollout(r, after='git-pillar-update') }}
