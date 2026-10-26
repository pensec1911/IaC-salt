{% from "unattended-upgrades/map.jinja" import unattended_upgrades with context %}
{%- set uu = unattended_upgrades %}

{#- A drop-in instead of patching 50unattended-upgrades / 20auto-upgrades:
   the shipped files stay untouched, this one is read after them. #}
unattended-upgrades-dropin:
  file.managed:
    - name: {{ uu.dropin }}
    - mode: '0644'
    - contents: |
        // Managed by Salt (formulas/unattended-upgrades) — do not edit.
        APT::Periodic::Update-Package-Lists "1";
        APT::Periodic::Unattended-Upgrade "1";
        Unattended-Upgrade::Automatic-Reboot "{{ 'true' if uu.automatic_reboot else 'false' }}";
        Unattended-Upgrade::Automatic-Reboot-Time "{{ uu.automatic_reboot_time }}";
        Unattended-Upgrade::Remove-Unused-Kernel-Packages "{{ 'true' if uu.remove_unused_kernel_packages else 'false' }}";
        Unattended-Upgrade::Remove-Unused-Dependencies "{{ 'true' if uu.remove_unused_dependencies else 'false' }}";
        {%- if uu.package_blacklist %}
        Unattended-Upgrade::Package-Blacklist {
        {%- for pkg in uu.package_blacklist %}
            "{{ pkg }}";
        {%- endfor %}
        };
        {%- endif %}
    - require:
      - pkg: unattended-upgrades-packages

unattended-upgrades-metrics-script:
  file.managed:
    - name: {{ uu.metrics.script }}
    - source: salt://unattended-upgrades/files/os-patch-metrics.py.j2
    - template: jinja
    - mode: '0755'
    - require:
      - sls: node-exporter
