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
