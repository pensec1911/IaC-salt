{% from "ntp/map.jinja" import ntp with context %}

ntp-packages:
  pkg.installed:
    - name: {{ ntp.pkg }}

{#- A drop-in instead of patching timesyncd.conf: the shipped file stays
   untouched, the drop-in overrides it. #}
ntp-timesyncd-dropin:
  file.managed:
    - name: {{ ntp.dropin }}
    - makedirs: True
    - mode: '0644'
    - contents: |
        # Managed by Salt (formulas/ntp) — do not edit.
        [Time]
        NTP={{ ntp.servers | join(' ') }}
        FallbackNTP={{ ntp.fallback_servers | join(' ') }}
    - require:
      - pkg: ntp-packages
