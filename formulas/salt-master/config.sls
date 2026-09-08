include:
  - salt-master.install

/etc/salt/master.d/gitfs.conf:
  file.managed:
    - source: salt://salt-master/files/gitfs.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: gitfs-deploy-key
    - watch_in:
      - service: salt-master-service

/etc/salt/master.d/git_pillar.conf:
  file.managed:
    - source: salt://salt-master/files/git_pillar.conf.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - cmd: gitfs-deploy-key
    - watch_in:
      - service: salt-master-service

/etc/salt/master.d/auto_accept.conf:
  file.managed:
    - source: salt://salt-master/files/auto_accept.conf
    - user: root
    - group: root
    - mode: '0644'
    - watch_in:
      - service: salt-master-service
