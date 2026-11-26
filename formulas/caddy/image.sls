{% from "caddy/map.jinja" import caddy with context %}

include:
  - podman

{#- The stock image + caddy-dns/porkbun, built here (map.jinja). Runs only
   when the tag is missing, i.e. on the first apply and after a version
   bump; it runs before the container macro's pull state, which then finds
   the image and doesn't try a registry. The builder image (~600 MB) is
   removed afterwards; old caddy-porkbun tags stay until
   `podman image prune -a`. #}
caddy-build-context:
  file.managed:
    - name: {{ caddy.build_dir }}/Containerfile
    - source: salt://caddy/files/Containerfile
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True

caddy-image-build:
  cmd.run:
    - name: >-
        podman build --pull=missing
        --build-arg CADDY_VERSION={{ caddy.tag }}
        --build-arg PORKBUN_VERSION={{ caddy.porkbun_version }}
        --tag {{ caddy.built_image }}:{{ caddy.ref_tag }}
        {{ caddy.build_dir }}
        && podman image rm --ignore {{ caddy.image }}:{{ caddy.tag }}-builder
    - unless: podman image exists {{ caddy.built_image }}:{{ caddy.ref_tag }}
    - require:
      - sls: podman
      - file: caddy-build-context
    - require_in:
      - cmd: caddy-container-image
