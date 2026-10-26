{#- Orchestrate SLS (not a state for a minion) — run on the master, by hand:
     salt-run state.orchestrate orch.rollout            # dry run on all, then apply in order
     salt-run state.orchestrate orch.rollout test=True  # touches nothing
   Rendered once up front: the minion list is fixed when the run starts.
   Mechanics and knobs: orch/map.jinja. #}
{%- from "orch/map.jinja" import orch with context %}
{%- set r = orch.rollout %}
{%- set pings = salt['saltutil.cmd'](r.tgt, 'test.ping', tgt_type=r.tgt_type, timeout=r.query_timeout) %}
{%- set up = [] %}
{%- for id, ret in pings | dictsort %}
{%-   if ret.get('ret') is sameas true %}
{%-     do up.append(id) %}
{%-   endif %}
{%- endfor %}
{%- set ordered = [] %}
{%- for id in r.order if id in up and id != r.master_id %}
{%-   do ordered.append(id) %}
{%- endfor %}
{%- for id in up if id not in r.order and id != r.master_id %}
{%-   do ordered.append(id) %}
{%- endfor %}
{%- if r.master_id and r.master_id in up %}
{%-   do ordered.append(r.master_id) %}
{%- endif %}

{%- if r.dry_run and ordered %}
{#- One test=True highstate on all of them: a render error or failing state
   anywhere stops the run before any minion changes. #}
dry-run:
  salt.state:
    - tgt: {{ ordered | join(',') | yaml_encode }}
    - tgt_type: list
    - highstate: True
    - test: True
    - queue: True
    - timeout: {{ r.apply_timeout }}
{%- endif %}

{%- for id in ordered %}
apply-{{ id }}:
  salt.state:
    - tgt: {{ id | yaml_encode }}
    - highstate: True
    - queue: True
    - timeout: {{ r.apply_timeout }}
{%-   if not loop.first %}
    - require:
      - salt: apply-{{ loop.previtem }}
{%-   elif r.dry_run %}
    - require:
      - salt: dry-run
{%-   endif %}
{%- endfor %}

{%- if not ordered %}
nothing-to-roll-out:
  test.succeed_without_changes:
    - name: no minion in {{ r.tgt }} answered
{%- endif %}
