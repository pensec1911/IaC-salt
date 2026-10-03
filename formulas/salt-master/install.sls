{% from "salt-master/map.jinja" import salt_master with context %}

salt-master-packages:
  pkg.installed:
    - pkgs:
      - git

# Salt ships as a onedir bundle here, so these have to go into *its*
# Python (via salt-pip), not the system one — a distro python3-pygit2
# would simply not be importable by the daemon.
#
#   pygit2       — the gitfs/git_pillar provider (see map.jinja).
#   saltext.vault — Vault/OpenBao support, moved out of Salt core into
#                   this extension as of 3007. Without it the sdb profile
#                   resolves but the driver is missing, and the only
#                   symptom is `KeyError: 'vault.get'`.
salt-master-python-deps:
  pip.installed:
    - pkgs:
      - pygit2
      - saltext.vault
    - bin_env: /usr/bin/salt-pip
    - reload_modules: True
    - require:
      - pkg: salt-master-packages

# Owned by the salt user, not root: the salt-master daemon runs as
# `salt` (user: salt in /etc/salt/master) and has to read the deploy key
# itself. A root-owned 0700 dir here means gitfs can't even traverse into
# it, and the failure surfaces as an authentication error, not a
# permission one.
gitfs-deploy-key-dir:
  file.directory:
    - name: {{ salt_master.deploy_key_dir }}
    - user: {{ salt_master.salt_user }}
    - group: {{ salt_master.salt_user }}
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
    - user: {{ salt_master.salt_user }}
    - group: {{ salt_master.salt_user }}
    - mode: '0600'
    - replace: False
    - require:
      - cmd: gitfs-deploy-key

gitfs-deploy-pubkey-perms:
  file.managed:
    - name: {{ salt_master.deploy_key_dir }}/id_ed25519.pub
    - user: {{ salt_master.salt_user }}
    - group: {{ salt_master.salt_user }}
    - mode: '0644'
    - replace: False
    - require:
      - cmd: gitfs-deploy-key

# Published GitHub host key, pinned here instead of trusting ssh-keyscan
# output at apply time (avoids a first-connection MITM window). Written to
# the system-wide /etc/ssh/ssh_known_hosts (no `user:` given) rather than
# root's ~/.ssh/known_hosts — git runs as the salt user, so a root-only
# entry would never be consulted and host key verification would fail.
github-known-host:
  ssh_known_hosts.present:
    - name: github.com
    - enc: ssh-ed25519
    - key: {{ salt_master.known_host_key }}
