{#- Orchestrate SLS (not a state for a minion) — run on the master:
     salt-run state.orchestrate orch.reboot            # nightly via orch-reboot.timer
     salt-run state.orchestrate orch.reboot test=True  # which minions, in what order
   Rendered once up front: the pending list is fixed when the run starts.
   Mechanics and knobs: orch/map.jinja. #}
{%- from "orch/map.jinja" import orch with context %}
{%- set r = orch.reboot %}
{%- set flags = salt['saltutil.cmd'](r.tgt, 'file.file_exists', arg=[r.flag_file], tgt_type=r.tgt_type, timeout=r.query_timeout) %}
{%- set pending = [] %}
{%- for id, ret in flags | dictsort %}
{%-   if ret.get('ret') is sameas true %}
{%-     do pending.append(id) %}
{%-   endif %}
{%- endfor %}
{%- set ordered = [] %}
{%- for id in r.order if id in pending and id != r.master_id %}
{%-   do ordered.append(id) %}
{%- endfor %}
{%- for id in pending if id not in r.order and id != r.master_id %}
{%-   do ordered.append(id) %}
{%- endfor %}

{%- for id in ordered %}
reboot-{{ id }}:
  salt.function:
    - name: system.reboot
    - tgt: {{ id | yaml_encode }}
    - kwarg:
        at_time: {{ r.delay_minutes }}
{%-   if not loop.first %}
    - require:
      - salt: converge-{{ loop.previtem }}
{%-   endif %}

{#- Starts listening right after system.reboot returns — the reboot itself
   is delay_minutes later, so the start event can't be missed. #}
wait-{{ id }}:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - id_list:
      - {{ id | yaml_encode }}
    - timeout: {{ r.boot_timeout }}
    - require:
      - salt: reboot-{{ id }}

{#- queue=True: lines up behind the start reactor's highstate, so this
   returns once the minion has converged (normally with 0 changes). #}
converge-{{ id }}:
  salt.state:
    - tgt: {{ id | yaml_encode }}
    - highstate: True
    - queue: True
    - timeout: {{ r.converge_timeout }}
    - require:
      - salt: wait-{{ id }}
{%- endfor %}

{%- if r.master_id and r.master_id in pending %}
{#- Last and without waiting: rebooting the master ends this run. #}
reboot-{{ r.master_id }}:
  salt.function:
    - name: system.reboot
    - tgt: {{ r.master_id | yaml_encode }}
    - kwarg:
        at_time: {{ r.delay_minutes }}
{%-   if ordered %}
    - require:
      - salt: converge-{{ ordered | last }}
{%-   endif %}
{%- endif %}

{%- if not pending %}
nothing-to-reboot:
  test.succeed_without_changes:
    - name: no minion has {{ r.flag_file }}
{%- endif %}
