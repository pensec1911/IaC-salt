{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. Fired by salt-api when Alertmanager posts to
   /hook/alertmanager (route in pillar/alertmanager.sls); `data` is
   {body: <raw>, post: <parsed JSON>, headers: {...}}. The hook needs no
   Salt auth, so the bearer token is the only proof of the sender — a
   missing or wrong one: nothing happens.

   Per firing alert, the minion it names gets its drift check now
   (schedule.run_job drift-check, formulas/salt-minion) — not a highstate:
   the check repairs only where enforce is on and its window open, so
   arrstack/jellyfin by day and wazuh stay report-only, as without this.
   Which minion: the IP in the `url` label (ProbeFailed, blackbox) as an
   ipcidr match — a non-minion host (NAS, router) matches nothing — else
   the `instance` label (TargetDown etc., = minion id). Both are matched
   against a strict pattern first; anything else is ignored. #}
{%- set expected = opts.get('homelab_alertmanager_token', '') %}
{%- set auth = data.get('headers', {}).get('Authorization', '') %}
{%- if expected and auth == 'Bearer ' ~ expected %}
{%-   set ips = [] %}
{%-   set ids = [] %}
{%-   for alert in data.get('post', {}).get('alerts', []) if alert.get('status') == 'firing' %}
{%-     set labels = alert.get('labels', {}) %}
{%-     if labels.get('url') %}
{%-       set m = labels.url | regex_search('^https?://([0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3}[.][0-9]{1,3})(:[0-9]+)?(/.*)?$') %}
{%-       if m and m[0] not in ips %}
{%-         do ips.append(m[0]) %}
{%-       endif %}
{%-     elif labels.get('instance') %}
{%-       set m = labels.instance | regex_match('^([a-z0-9][a-z0-9-]*)$') %}
{%-       if m and m[0] not in ids %}
{%-         do ids.append(m[0]) %}
{%-       endif %}
{%-     endif %}
{%-   endfor %}
{%-   for ip in ips %}
drift-check-{{ ip }}:
  local.schedule.run_job:
    - tgt: {{ ip | yaml_encode }}
    - tgt_type: ipcidr
    - args:
      - name: drift-check
{%-   endfor %}
{%-   if ids %}
drift-check-minions:
  local.schedule.run_job:
    - tgt: {{ ids | join(',') | yaml_encode }}
    - tgt_type: list
    - args:
      - name: drift-check
{%-   endif %}
{%- endif %}
