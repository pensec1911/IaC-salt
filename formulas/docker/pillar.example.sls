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
    # /etc/docker/daemon.json, rendered 1:1. Changing it restarts docker
    # (all containers on the host). log-opts only affect newly created
    # containers.
    daemon_config_file: /etc/docker/daemon.json
    daemon_config:
      log-driver: json-file
      log-opts:
        max-size: 10m
        max-file: "3"
