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

{% if salt_master.vault_ca_cert %}
# OpenBao's CA/server cert, so the master can verify its TLS cert. Public
# data, not a secret — it lives in pillar (salt-master:lookup:vault_ca_cert)
# like any other environment-specific value, rather than in this formula.
{{ salt_master.vault_ca_cert_file }}:
  file.managed:
    - contents_pillar: salt-master:lookup:vault_ca_cert
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - require:
      - pkg: salt-master-packages
{% endif %}

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
{%- if salt_master.vault_ca_cert %}
      - file: {{ salt_master.vault_ca_cert_file }}
{%- endif %}
    - watch_in:
      - service: salt-master-service
