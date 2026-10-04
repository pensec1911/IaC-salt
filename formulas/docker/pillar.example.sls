# Optional overrides for salt/docker. Everything here has a working default
# (see docker/map.jinja) — only set what you need to change.
docker:
  lookup:
    pkgs:
      - docker-ce
      - docker-ce-cli
      - containerd.io
    # Installed into Salt's onedir Python, not the system one.
    salt_pip_pkgs:
      - saltext.dockermod
      - docker
    salt_pip_bin: /usr/bin/salt-pip
    repo_baseurl: https://download.docker.com/linux/debian
    repo_keyurl: https://download.docker.com/linux/debian/gpg
    keyring: /etc/apt/keyrings/docker.asc
    service: docker
