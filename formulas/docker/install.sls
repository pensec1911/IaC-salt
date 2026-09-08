{% from "docker/map.jinja" import docker with context %}

docker-prereqs:
  pkg.installed:
    - pkgs:
      - ca-certificates
      - curl
      - gnupg

docker-repo-key:
  file.managed:
    - name: {{ docker.keyring }}
    - source: {{ docker.repo_keyurl }}
    - skip_verify: True
    - makedirs: True
    - require:
      - pkg: docker-prereqs

docker-repo:
  pkgrepo.managed:
    - name: deb [arch={{ grains['osarch'] }} signed-by={{ docker.keyring }}] {{ docker.repo_baseurl }} {{ grains['oscodename'] }} stable
    - file: /etc/apt/sources.list.d/docker.list
    - require:
      - file: docker-repo-key

docker-packages:
  pkg.installed:
    - pkgs: {{ docker.pkgs }}
    - require:
      - pkgrepo: docker-repo
