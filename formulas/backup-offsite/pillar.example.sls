# Real data goes in pillar/backup-offsite.sls (salt-master only, pillar/top.sls).
backup_offsite:
  lookup:
    # IaC-opentofu: tofu -chdir=oci output restic_offsite_repository
    repository: "s3:https://<namespace>.compat.objectstorage.eu-frankfurt-1.oraclecloud.com/homelab-restic"
    region: eu-frankfurt-1
    # Always sdb references, never literals (README "Bootstrap").
    password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?password') | yaml_encode }}
    access_key_id: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?access_key_id') | yaml_encode }}
    secret_access_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?secret_access_key') | yaml_encode }}
    # Password of the NAS repos, plus repos with their own.
    source_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/repo?password') | yaml_encode }}
    source_passwords:
      cloud-edge: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/cloud-edge?password') | yaml_encode }}
    # Defaults (map.jinja): keep (7d/4w/12m), on_calendar 03:15, source_base …
