{% from "nfs-mount/map.jinja" import nfs_mount with context %}

nfs-mount-prereqs:
  pkg.installed:
    - name: nfs-common
{%- for mnt in salt['pillar.get']('nfs_mounts', []) %}

nfs-mount-{{ mnt.name }}:
  mount.mounted:
    - name: {{ mnt.mountpoint }}
    - device: {{ mnt.server }}:{{ mnt.export }}
    - fstype: {{ mnt.get('fstype', nfs_mount.default_fstype) }}
    - opts: {{ mnt.get('opts', nfs_mount.default_opts) }}
    - mkmnt: True
    - persist: True
    - require:
      - pkg: nfs-mount-prereqs
{%- endfor %}

{#- Units that must not start before (or without) the mounts — e.g. docker,
   whose bind mounts would otherwise land on the empty local mountpoint
   when the NAS is slow at boot. RequiresMountsFor= adds Requires= + After=
   on the mount units: if a mount fails, the unit fails too instead of
   running against the wrong directory. Takes effect on the unit's next
   start; the running unit isn't restarted. #}
{%- set mountpoints = salt['pillar.get']('nfs_mounts', []) | map(attribute='mountpoint') | list %}
{%- for unit in nfs_mount.required_by %}

nfs-mount-required-by-{{ unit }}:
  file.managed:
    - name: /etc/systemd/system/{{ unit }}.d/nfs-mounts.conf
    - makedirs: True
    - contents: |
        # Managed by Salt (formulas/nfs-mount) — do not edit.
        [Unit]
        RequiresMountsFor={{ mountpoints | join(' ') }}
    - require:
{%- for mnt in salt['pillar.get']('nfs_mounts', []) %}
      - mount: nfs-mount-{{ mnt.name }}
{%- endfor %}
{%- endfor %}
{%- if nfs_mount.required_by %}

nfs-mount-systemd-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
{%- for unit in nfs_mount.required_by %}
      - file: nfs-mount-required-by-{{ unit }}
{%- endfor %}
{%- endif %}
