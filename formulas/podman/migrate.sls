{% from "podman/map.jinja" import podman with context %}

{#- One runtime per VM: Docker goes down before any Quadlet unit starts (the
   container states require this sls), so published ports are free and
   nothing runs twice. Its containers stay in /var/lib/docker, stopped —
   the way back is re-enabling docker (README "Migration from Docker").
   No-op on a host without Docker (onlyif). #}
{%- for unit in podman.docker_units %}

podman-docker-off-{{ unit }}:
  service.dead:
    - name: {{ unit }}
    - enable: False
    - onlyif: systemctl cat {{ unit }}
{%- endfor %}

{#- Docker leaves its iptables rules behind when it stops, among them
   FORWARD policy DROP, which drops every forwarded packet of netavark's
   bridge (no egress from containers — seen on homepage, 2026-11-12). On
   these VMs every iptables rule was Docker's (checked on all five), so its
   tables go entirely — the state after a reboot without Docker. netavark's
   rules are in their own nft table (map.jinja firewall_driver) and stay.
   Runs only while a Docker chain is still present. #}
podman-docker-firewall-cleanup:
  cmd.run:
    - name: |
        for t in "ip filter" "ip nat" "ip raw" "ip mangle" "ip6 filter" "ip6 nat" "ip6 raw" "ip6 mangle"; do
          if nft list table $t >/dev/null 2>&1; then nft delete table $t; fi
        done
    - onlyif: nft list ruleset | grep -q DOCKER
    - require:
{%- for unit in podman.docker_units %}
      - service: podman-docker-off-{{ unit }}
{%- endfor %}
