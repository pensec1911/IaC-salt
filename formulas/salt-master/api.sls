{% from "salt-master/map.jinja" import salt_master with context %}

include:
  - salt-master.install
  - salt-master.service

{% if salt_master.api_enabled %}
# Pinned to the installed salt-master: salt-api depends on salt-master of
# exactly its own version, so installing the repo's newest salt-api would
# upgrade the master on the side (the Salt repo is excluded from
# unattended-upgrades for a reason).
salt-api-package:
  pkg.installed:
    - name: salt-api
    - version: {{ salt['pkg.version']('salt-master') | yaml_encode }}
    - require:
      - pkg: salt-master-packages

salt-api-tls-dir:
  file.directory:
    - name: {{ salt_master.api_tls_dir }}
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0750'
    - makedirs: True

# Cert and key are placed by hand (README "salt-api TLS") — TLS bootstrap
# stays manual. Only existence is checked and the key's perms enforced: the
# api runs as the salt user and must read it, nobody else may.
salt-api-tls-crt-present:
  file.exists:
    - name: {{ salt_master.api_ssl_crt }}
    - require:
      - file: salt-api-tls-dir

salt-api-tls-key-present:
  file.exists:
    - name: {{ salt_master.api_ssl_key }}
    - require:
      - file: salt-api-tls-dir

salt-api-tls-key-perms:
  file.managed:
    - name: {{ salt_master.api_ssl_key }}
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0640'
    - replace: False
    - require:
      - file: salt-api-tls-key-present

# 0640 like vault.conf: carries the Alertmanager hook token in clear. Read
# by salt-api (rest_cherrypy) and by the master (the token, for the reactor).
/etc/salt/master.d/api.conf:
  file.managed:
    - source: salt://salt-master/files/api.conf.j2
    - template: jinja
    - user: root
    - group: {{ salt_master.salt_user }}
    - mode: '0640'
    - show_changes: False
    - require:
      - pkg: salt-api-package
    - watch_in:
      - service: salt-master-service

salt-api-service:
  service.running:
    - name: salt-api
    - enable: True
    - require:
      - file: salt-api-tls-crt-present
      - file: salt-api-tls-key-perms
      - service: salt-master-service
    - watch:
      - file: /etc/salt/master.d/api.conf
      - pkg: salt-api-package

{% else %}
salt-api-service:
  service.dead:
    - name: salt-api
    - enable: False

/etc/salt/master.d/api.conf:
  file.absent:
    - require:
      - service: salt-api-service
    - watch_in:
      - service: salt-master-service
{% endif %}
