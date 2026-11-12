{% from "podman/map.jinja" import podman with context %}
{%- set line = podman.subid.name ~ ':' ~ podman.subid.start ~ ':' ~ podman.subid.size %}

{#- Only our line; the login accounts' entries useradd wrote stay. #}
{%- for path in podman.subid.files %}

podman-subid-{{ path }}:
  file.replace:
    - name: {{ path }}
    - pattern: '^{{ podman.subid.name }}:.*$'
    - repl: {{ line }}
    - append_if_not_found: True
    - require:
      - pkg: podman-packages
{%- endfor %}

podman-containers-conf:
  file.managed:
    - name: {{ podman.conf_dropin }}
    - makedirs: True
    - mode: '0644'
    - contents: |
        # Managed by Salt (formulas/podman) — do not edit.
        [containers]
        log_driver = "{{ podman.log_driver }}"

        [network]
        firewall_driver = "{{ podman.firewall_driver }}"
    - require:
      - pkg: podman-packages

podman-quadlet-dir:
  file.directory:
    - name: {{ podman.quadlet_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{#- See map.jinja apparmor_disable. disable/ keeps it out at boot; the
   parser call takes it out of the running kernel. podman-apparmor-unload
   reports a change only when it actually unloaded something — the
   container macro watches it. #}
{%- for profile in podman.apparmor_disable %}

podman-apparmor-disable-{{ profile }}:
  file.symlink:
    - name: /etc/apparmor.d/disable/{{ profile }}
    - target: /etc/apparmor.d/{{ profile }}
    - makedirs: True
    - onlyif: test -f /etc/apparmor.d/{{ profile }}
{%- endfor %}

podman-apparmor-unload:
  cmd.run:
    - name: |
{%- for profile in podman.apparmor_disable %}
        if grep -q '^{{ profile }} ' /sys/kernel/security/apparmor/profiles; then {{ podman.apparmor_parser }} -R /etc/apparmor.d/{{ profile }}; fi
{%- endfor %}
    - onlyif: grep -qE '^({{ podman.apparmor_disable | join('|') }}) ' /sys/kernel/security/apparmor/profiles
    - require:
{%- for profile in podman.apparmor_disable %}
      - file: podman-apparmor-disable-{{ profile }}
{%- endfor %}
