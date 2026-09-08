{% from "salt-master/map.jinja" import salt_master with context %}

salt-master-packages:
  pkg.installed:
    - pkgs:
      - git
      - python3-git

gitfs-deploy-key-dir:
  file.directory:
    - name: {{ salt_master.deploy_key_dir }}
    - user: root
    - group: root
    - mode: '0700'
    - makedirs: True

gitfs-deploy-key:
  cmd.run:
    - name: ssh-keygen -t ed25519 -N '' -C 'salt-master-gitfs' -f {{ salt_master.deploy_key_dir }}/id_ed25519
    - creates: {{ salt_master.deploy_key_dir }}/id_ed25519
    - require:
      - file: gitfs-deploy-key-dir

gitfs-deploy-key-perms:
  file.managed:
    - name: {{ salt_master.deploy_key_dir }}/id_ed25519
    - user: root
    - group: root
    - mode: '0600'
    - replace: False
    - require:
      - cmd: gitfs-deploy-key

# Published GitHub host key, pinned here instead of trusting ssh-keyscan
# output at apply time (avoids a first-connection MITM window).
github-known-host:
  ssh_known_hosts.present:
    - name: github.com
    - user: root
    - enc: ssh-ed25519
    - key: {{ salt_master.known_host_key }}
