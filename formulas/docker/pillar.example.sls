# Optional overrides for salt/docker. Everything here has a working default
# (see docker/map.jinja) — only set what you need to change.
docker:
  lookup:
    pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - python3-docker
    repo_baseurl: https://download.docker.com/linux/debian
    repo_keyurl: https://download.docker.com/linux/debian/gpg
    keyring: /etc/apt/keyrings/docker.asc
    service: docker
