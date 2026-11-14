# Real data: pillar/patchmon-agent.sls (all minions), referenced from
# pillar/top.sls. This file just documents the schema.

patchmon-agent:
  lookup:
    server_url: http://192.168.178.29:3001
    # One auto-enrollment token for all minions (README "Enrolment").
    # Missing in OpenBao = minions without credentials stay un-enrolled:
    # binary only, no service.
    enroll_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/enroll?key') | yaml_encode }}
    enroll_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/enroll?secret') | yaml_encode }}
    # Optional — overrides for formulas/patchmon-agent/map.jinja defaults.
    # version and sha256 move together (sha256 of patchmon-agent-linux-amd64
    # from the release's SHA256SUMS).
    version: '2.1.8'
    sha256: 6c143ec193153513f677b0b114f52aa0b6bf2554c95f407a016e3d20d9ad680c
    log_level: info
    bin: /usr/local/bin/patchmon-agent
    config_dir: /etc/patchmon
    unit: patchmon-agent
    enroll_script: /usr/local/sbin/patchmon-agent-enroll
