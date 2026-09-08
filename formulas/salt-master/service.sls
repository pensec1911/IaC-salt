include:
  - salt-master.install

salt-master-service:
  service.running:
    - name: salt-master
    - enable: True
    - require:
      - pkg: salt-master-packages
