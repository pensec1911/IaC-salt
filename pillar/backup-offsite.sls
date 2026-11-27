{#- formulas/backup-offsite on salt-master: nightly restic copy of every NAS
   repo (formulas/backup) into the OCI bucket homelab-restic (IaC-opentofu
   oci/offsite.tf). Source passwords mirror password_path in
   pillar/backup.sls — a minion with its own repo password needs it here
   too, else its copy fails with "wrong password". #}
backup_offsite:
  lookup:
    # tofu -chdir=oci output restic_offsite_repository
    repository: "REPOSITORY_PLACEHOLDER"
    region: eu-frankfurt-1
    password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?password') | yaml_encode }}
    access_key_id: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?access_key_id') | yaml_encode }}
    secret_access_key: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/offsite?secret_access_key') | yaml_encode }}
    source_password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/repo?password') | yaml_encode }}
    source_passwords:
      cloud-edge: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/cloud-edge?password') | yaml_encode }}
      salt-master: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/salt-master?password') | yaml_encode }}
