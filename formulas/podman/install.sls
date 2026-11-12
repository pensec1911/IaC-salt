{% from "podman/map.jinja" import podman with context %}

podman-packages:
  pkg.installed:
    - pkgs: {{ podman.pkgs | json }}
