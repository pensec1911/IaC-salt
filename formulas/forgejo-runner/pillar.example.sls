# Real data for this minion goes in pillar/forgejo.sls (same VM as
# Forgejo), referenced from pillar/top.sls. This file just documents the
# schema.
#
# Also requires (see formulas/users):
#   - users:accounts entry "forgejo-runner" with a PINNED uid/gid (must match
#     forgejo-runner:lookup:uid/gid below)
# and the same secret registered on the Forgejo side
# (forgejo:lookup:runners:<name>:secret, formulas/forgejo).

forgejo-runner:
  lookup:
    tag: 13.2.0
    dind_tag: 29.9.2-dind
    uid: 973
    gid: 973
    data_dir: /opt/forgejo-runner/data
    dind_dir: /opt/forgejo-runner/dind
    instance_url: http://192.168.178.29:3000/
    # 40 lowercase hex chars, always from OpenBao:
    secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/forgejo/runner?secret') | yaml_encode }}
    capacity: 1
    labels:
      - docker:docker://node:22-bookworm
