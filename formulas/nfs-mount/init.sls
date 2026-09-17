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
