{#- Pins this host's Salt packages to the effective version (map.jinja:
   version) so a stray `apt upgrade` can't move them. Upgrades nothing:
   that's upgrade.sls, run only by orch.salt-upgrade (formulas/orch). An
   installed version newer than the pin fails here — the master would be
   older than this minion, or a VM came from Tofu with a newer 3008.*. #}
{% from "salt-minion/map.jinja" import salt_minion with context %}
{%- set v = salt_minion.version %}

{%- if v.effective %}

salt-minion-version-pin:
  file.managed:
    - name: {{ v.pin_file }}
    - mode: '0644'
    - contents: |
        # Managed by Salt (formulas/salt-minion version.sls) — do not edit here.
        # Bump salt-minion:lookup:version:target, then orch.salt-upgrade.
        Package: {{ v.pin_package }}
        Pin: version {{ v.effective }}
        Pin-Priority: {{ v.pin_priority }}

{%-   for pkg in v.packages %}
{%-     set installed = salt['pkg.version'](pkg) %}
{%-     if installed and salt['pkg.version_cmp'](installed, v.effective) > 0 %}

salt-minion-version-newer-{{ pkg }}:
  test.fail_without_changes:
    - name: {{ pkg }} {{ installed }} is newer than the pinned {{ v.effective }} — raise salt-minion:lookup:version:target (master first) or downgrade by hand
{%-     endif %}
{%-   endfor %}

{%- endif %}
