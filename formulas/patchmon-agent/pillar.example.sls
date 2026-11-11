# Real data: pillar/patchmon-agent.sls (all minions), referenced from
# pillar/top.sls. This file just documents the schema.

patchmon-agent:
  lookup:
    server_url: http://192.168.178.29:3001
    # Per minion, created in the PatchMon UI (README "Enrol a minion").
    # Missing in OpenBao = not enrolled: binary only, no service.
    api_id: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/agent/' ~ grains['id'] ~ '?api_id') | yaml_encode }}
    api_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/agent/' ~ grains['id'] ~ '?api_key') | yaml_encode }}
    # Optional — overrides for formulas/patchmon-agent/map.jinja defaults.
    # version and sha256 move together (sha256 of patchmon-agent-linux-amd64
    # from the release's SHA256SUMS).
    version: '2.1.8'
    sha256: 6c143ec193153513f677b0b114f52aa0b6bf2554c95f407a016e3d20d9ad680c
    log_level: info
    bin: /usr/local/bin/patchmon-agent
    config_dir: /etc/patchmon
    unit: patchmon-agent
