{#- cloud-edge: OCI A1.Flex (arm64), IaC-opentofu oci/. Reaches the LAN only
   through the WireGuard tunnel to gateway (wg0 10.99.0.1); the FRITZ!Box
   routes 10.99.0.0/24 to gateway, so the LAN sees it under its wg0 address.
   NTP override: pillar/ntp.sls. #}

{#- Prometheus reads its targets from the Mine: publish the wg0 address, not
   the VCN-private one on the OCI NIC (named enp0s*, not eth0). #}
node-exporter:
  lookup:
    mine:
      interface: wg0

cadvisor:
  lookup:
    mine:
      interface: wg0

{#- The default pin is the amd64 binary. Same version, arm64 asset; sha256 =
   GitHub's release digest (checked 2026-11-25). Bump together with the
   default in formulas/patchmon-agent/map.jinja. #}
patchmon-agent:
  lookup:
    url: https://github.com/PatchMon/PatchMon/releases/download/v{version}/patchmon-agent-linux-arm64
    sha256: 416c4127b16182a1e99e307b11f222b7407622625393c61f1904495fed97011d
