# No pillar required — the defaults in formulas/toolbox/map.jinja are complete.
# Overrides, if ever needed, go in pillar/toolbox.sls (referenced from pillar/top.sls).

toolbox:
  lookup:
    cyberchef:
      tag: 11.5.0
      host_port: 8081
    it_tools:
      tag: 2024.10.22-7ca5933
      host_port: 8082
      # Any podman container spec key (formulas/podman README), merged last.
      podman: {}
