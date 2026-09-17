{% from "salt-master/map.jinja" import salt_master with context %}

include:
  - salt-master.install

# AppRole secret_id is never committed — it must exist on the master ahead
# of this state applying cleanly (same bootstrap spirit as the gitfs
# deploy key, but this one comes from OpenBao, not ssh-keygen, so it can't
# be generated locally). See formulas/salt-master/README.md.
vault-secret-id-present:
  file.exists:
    - name: {{ salt_master.vault_secret_id_file }}

/etc/salt/master.d/vault.conf:
  file.managed:
    - source: salt://salt-master/files/vault.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - pkg: salt-master-packages
      - file: vault-secret-id-present
    - watch_in:
      - service: salt-master-service
