# Optional overrides for formulas/podman. Everything has a working default
# (podman/map.jinja) — only set what you need to change.
podman:
  lookup:
    pkgs: [podman, crun, netavark, aardvark-dns, catatonit]
    quadlet_dir: /etc/containers/systemd
    log_driver: journald
    firewall_driver: nftables
    # Range for --userns=auto. Must not overlap the login accounts' ranges
    # (100000+, written by useradd).
    subid:
      name: containers
      start: 2147483647
      size: 2147483648
    # Stopped and disabled on a host that still has Docker (podman.migrate).
    docker_units: [docker.socket, docker.service, containerd.service]
    # Defaults for every container spec (README "Container spec"). Per
    # container, use the owning formula's <formula>:lookup:podman instead.
    container:
      stop_timeout: 60
      timeout_start_sec: 900
