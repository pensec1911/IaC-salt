{% from "nfs-mount/map.jinja" import nfs_mount with context %}

nfs-mount-prereqs:
  pkg.installed:
    - name: nfs-common
{%- for mnt in salt['pillar.get']('nfs_mounts', []) %}
{%-   set opts = mnt.get('opts', nfs_mount.default_opts) | list %}
{%-   set wait = mnt.get('boot_wait_minutes', nfs_mount.boot_wait_minutes) | int %}
{#-   Boot wait (map.jinja boot_wait_minutes). Salt counts nofail, retry and
      (via extra_mount_invisible_keys) the systemd key as invisible, so
      adding them never remounts a live share. #}
{%-   set has = namespace(retry=False, timeout=False) %}
{%-   for o in opts %}
{%-     if o.startswith('retry=') %}{% set has.retry = True %}{% endif %}
{%-     if o.startswith('x-systemd.mount-timeout=') %}{% set has.timeout = True %}{% endif %}
{%-   endfor %}
{%-   if wait > 0 %}
{%-     if 'nofail' not in opts %}{% do opts.append('nofail') %}{% endif %}
{%-     if not has.retry %}{% do opts.append('retry=' ~ wait) %}{% endif %}
{%-     if not has.timeout %}{% do opts.append('x-systemd.mount-timeout=' ~ (wait + 1) ~ 'min') %}{% endif %}
{%-   endif %}

nfs-mount-{{ mnt.name }}:
  mount.mounted:
    - name: {{ mnt.mountpoint }}
    - device: {{ mnt.server }}:{{ mnt.export }}
    - fstype: {{ mnt.get('fstype', nfs_mount.default_fstype) }}
    - opts: {{ opts | json }}
    - extra_mount_invisible_keys:
      - x-systemd.mount-timeout
    - mkmnt: True
    - persist: True
    - require:
      - pkg: nfs-mount-prereqs
{%- endfor %}

{#- fstab changed → let systemd regenerate the mount units now, not only at
   the next boot (else it warns "fstab modified, run daemon-reload"). #}
{%- if salt['pillar.get']('nfs_mounts', []) %}

nfs-mount-fstab-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
{%-   for mnt in salt['pillar.get']('nfs_mounts', []) %}
      - mount: nfs-mount-{{ mnt.name }}
{%-   endfor %}
{%- endif %}

{#- Units that must not start before (or without) the mounts — e.g. a service,
   whose bind mounts would otherwise land on the empty local mountpoint
   when the NAS is slow at boot. RequiresMountsFor= adds Requires= + After=
   on the mount units: if a mount fails, the unit fails too instead of
   running against the wrong directory. Takes effect on the unit's next
   start; the running unit isn't restarted. A mount with
   `skip_required_by: true` (e.g. the backup share, which no container
   binds) stays out of it. #}
{%- set required = [] %}
{%- for mnt in salt['pillar.get']('nfs_mounts', []) if not mnt.get('skip_required_by', False) %}
{%- do required.append(mnt) %}
{%- endfor %}
{%- set mountpoints = required | map(attribute='mountpoint') | list %}
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
{%- for mnt in required %}
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
