{#- Upgrades this host's installed Salt packages to the effective version
   (map.jinja: version). Not in init.sls — only orch.salt-upgrade
   (formulas/orch) applies it, master first, then one minion at a time.

   The apt run happens in a transient systemd unit, delay_seconds later and
   once the minion is idle: the package restarts salt-minion itself, which
   would kill an apt this job started. So this state returns "scheduled";
   orch.salt-upgrade waits for the minion's start event and checks the
   version. Nothing to do -> no change. #}
{% from "salt-minion/map.jinja" import salt_minion with context %}
{%- set v = salt_minion.version %}
{%- set u = v.upgrade %}

include:
  - salt-minion.version

{%- set installed = [] %}
{%- set behind = [] %}
{%- for pkg in v.packages %}
{%-   set ver = salt['pkg.version'](pkg) %}
{%-   if ver %}
{%-     do installed.append(pkg) %}
{%-     if v.effective and salt['pkg.version_cmp'](ver, v.effective) < 0 %}
{%-       do behind.append(pkg ~ ' ' ~ ver) %}
{%-     endif %}
{%-   endif %}
{%- endfor %}

salt-minion-upgrade-script:
  file.managed:
    - name: {{ u.script }}
    - source: salt://salt-minion/files/salt-upgrade.sh.j2
    - template: jinja
    - mode: '0755'
    - context:
        u: {{ u | json }}

{%- if behind %}

{#- behind {{ v.effective }}: {{ behind | join(', ') }} #}
salt-minion-upgrade:
  cmd.run:
    - name: >-
        systemd-run --unit={{ u.unit }} --collect
        --description="Salt upgrade to {{ v.effective }}"
        --on-active={{ u.delay_seconds }}s
        {{ u.script }} {{ v.effective }}
        {%- for pkg in installed %} {{ pkg }}{% endfor %}
    # An upgrade already scheduled or running: leave it alone.
    - unless: systemctl is-active --quiet {{ u.unit }}.timer || systemctl is-active --quiet {{ u.unit }}.service
    - require:
      - file: salt-minion-upgrade-script
      - file: salt-minion-version-pin

{%- else %}

salt-minion-upgrade:
  test.succeed_without_changes:
    - name: Salt packages already at {{ v.effective or 'their unmanaged version' }}

{%- endif %}
