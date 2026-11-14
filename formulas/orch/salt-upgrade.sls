{#- Orchestrate SLS (not a state for a minion) — run on the master, by hand:
     salt-run state.orchestrate orch.salt-upgrade test=True  # who is behind, what happens
     salt-run state.orchestrate orch.salt-upgrade            # master first; run again for the minions
   Rendered once up front: the behind list is fixed when the run starts.
   Mechanics and knobs: orch/map.jinja (salt_upgrade). #}
{%- from "orch/map.jinja" import orch with context %}
{%- set r = orch.salt_upgrade %}
{%- set target = salt['pillar.get'](r.target_key, '') | string %}
{%- set versions = salt['saltutil.cmd'](r.tgt, 'pkg.version', arg=[r.package], tgt_type=r.tgt_type, timeout=r.query_timeout) if target else {} %}
{%- set behind = [] %}
{%- for id, ret in versions | dictsort %}
{%-   set have = ret.get('ret') %}
{%-   if have is string and have and salt['pkg.version_cmp'](have, target) < 0 %}
{%-     do behind.append(id) %}
{%-   endif %}
{%- endfor %}

{%- if not target %}
no-target:
  test.fail_without_changes:
    - name: {{ r.target_key }} is not set in pillar

{%- elif r.master_id and r.master_id in behind %}
{#- Master first, and alone: its upgrade restarts salt-master, which ends
   this run. Fire-and-forget like orch.rollout's last step. #}
upgrade-{{ r.master_id }}:
  salt.state:
    - tgt: {{ r.master_id | yaml_encode }}
    - sls: {{ r.sls }}
    - queue: True
    - timeout: {{ r.apply_timeout }}

then-run-again:
  test.show_notification:
    - text: >-
        {{ r.master_id }} upgrades to {{ target }} in the background (journalctl -u
        salt-upgrade there). Once it is back, run orch.salt-upgrade again for
        {{ (behind | reject('equalto', r.master_id) | join(', ')) or 'the rest' }}.
    - require:
      - salt: upgrade-{{ r.master_id }}

{%- else %}
{%-   set ordered = [] %}
{%-   for id in r.order if id in behind and id != r.master_id %}
{%-     do ordered.append(id) %}
{%-   endfor %}
{%-   for id in behind if id not in r.order and id != r.master_id %}
{%-     do ordered.append(id) %}
{%-   endfor %}

{%-   for id in ordered %}
upgrade-{{ id }}:
  salt.state:
    - tgt: {{ id | yaml_encode }}
    - sls: {{ r.sls }}
    - queue: True
    - timeout: {{ r.apply_timeout }}
{%-     if not loop.first %}
    - require:
      - salt: converge-{{ loop.previtem }}
{%-     endif %}

{#- Listens right after the state returns; the apt run starts
   delay_seconds later at the earliest (formulas/salt-minion). #}
wait-{{ id }}:
  salt.wait_for_event:
    - name: salt/minion/*/start
    - id_list:
      - {{ id | yaml_encode }}
    - timeout: {{ r.restart_timeout }}
    - require:
      - salt: upgrade-{{ id }}

verify-{{ id }}:
  salt.function:
    - name: cmd.run
    - tgt: {{ id | yaml_encode }}
    - arg:
      - {{ ('dpkg --compare-versions "$(dpkg-query -W -f=\'${Version}\' ' ~ r.package ~ ')" eq ' ~ target ~ ' && echo ok') | yaml_encode }}
    - kwarg:
        python_shell: True
    - require:
      - salt: wait-{{ id }}

{#- queue=True: lines up behind the start reactor's highstate. #}
converge-{{ id }}:
  salt.state:
    - tgt: {{ id | yaml_encode }}
    - highstate: True
    - queue: True
    - timeout: {{ r.converge_timeout }}
    - require:
      - salt: verify-{{ id }}
{%-   endfor %}

{%-   if not ordered %}
nothing-to-upgrade:
  test.succeed_without_changes:
    - name: every answering minion in {{ r.tgt }} runs {{ target }}
{%-   endif %}
{%- endif %}
