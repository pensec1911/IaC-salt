# Real values: pillar/oxidized.sls + pillar/oxidized.jinja (monitoring). Defaults: map.jinja.
# Nothing renders until enabled — enable only together with resolved keys and at least
# one device (pillar/oxidized.jinja does exactly that).

oxidized:
  lookup:
    enabled: True
    host_port: 8888
    interval: 3600
    remote_repo: ssh://git@192.168.178.29:2222/homelab/network-configs.git
    forgejo_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/oxidized/forgejo?ssh_key') | yaml_encode }}
    forgejo_key_pub: {{ salt['sdb.get']('sdb://osvault/homelab/data/oxidized/forgejo?ssh_key_pub') | yaml_encode }}
    known_hosts:
      - host: 192.168.178.29
        port: 2222
        enc: ssh-rsa
        key: AAAA...            # ssh-keyscan -p 2222 192.168.178.29
    devices:
      opnsense:
        model: opnsense         # Oxidized model name
        host: 192.168.x.y
        port: 22
        username: oxidized      # read-only device account, key auth
        host_key:
          enc: ssh-ed25519
          key: AAAA...          # ssh-keyscan <host>
        ssh_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/oxidized/opnsense?ssh_key') | yaml_encode }}
    # Any podman container spec key (formulas/podman README), merged last.
    podman: {}
