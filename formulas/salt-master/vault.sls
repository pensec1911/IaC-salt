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

# Contents are left alone (replace: False) — only ownership is enforced,
# because the salt-master daemon runs as `salt` and a root-only 0600 file
# is unreadable to it. That failure shows up as an AppRole auth error with
# nothing pointing at permissions, so it's worth asserting here rather
# than leaving it to whoever placed the file by hand.
vault-secret-id-perms:
  file.managed:
    - name: {{ salt_master.vault_secret_id_file }}
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0640'
    - replace: False
    - require:
      - file: vault-secret-id-present

{% if salt_master.vault_ca_cert %}
# OpenBao's CA/server cert, so the master can verify its TLS cert. Public
# data, not a secret — it lives in pillar (salt-master:lookup:vault_ca_cert)
# like any other environment-specific value, rather than in this formula.
{{ salt_master.vault_ca_cert_file }}:
  file.managed:
    - contents_pillar: salt-master:lookup:vault_ca_cert
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0644'
    - makedirs: True
    - require:
      - pkg: salt-master-packages
{% endif %}

# Group-readable by the salt user, not root-only: this is master config,
# read by the daemon itself, and an unreadable file in /etc/salt/master.d/
# doesn't just disable vault — it makes *every* salt/salt-run invocation
# die with PermissionError. 0640 root:<salt user> is as tight as it can
# get: the rendered file does contain the AppRole secret_id in clear
# (see the template for why it can't be a path), so it must not be
# world-readable like the other master.d confs.
/etc/salt/master.d/vault.conf:
  file.managed:
    - source: salt://salt-master/files/vault.conf.j2
    - template: jinja
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0640'
    - require:
      - pkg: salt-master-packages
      - file: vault-secret-id-perms
{%- if salt_master.vault_ca_cert %}
      - file: {{ salt_master.vault_ca_cert_file }}
{%- endif %}
    - watch_in:
      - service: salt-master-service
