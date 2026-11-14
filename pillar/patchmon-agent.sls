{#- formulas/patchmon-agent on every minion. One auto-enrollment token for
   all minions in OpenBao patchmon/enroll (key, secret); a minion without
   credentials enrols itself with it (formulas/patchmon-agent README
   "Enrolment"). #}
patchmon-agent:
  lookup:
    server_url: http://192.168.178.29:3001
    enroll_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/enroll?key') | yaml_encode }}
    enroll_secret: {{ salt['sdb.get']('sdb://osvault/homelab/data/patchmon/enroll?secret') | yaml_encode }}
