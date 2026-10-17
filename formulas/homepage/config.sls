{% from "homepage/map.jinja" import homepage with context %}

{#- Owned by puid/pgid, not root: the container chowns its config dir to
   PUID/PGID on every start, so root ownership here flip-flopped on each
   state.apply and replaced the container every time. #}
homepage-config-dir:
  file.directory:
    - name: {{ homepage.config_dir }}
    - user: {{ homepage.puid }}
    - group: {{ homepage.pgid }}
    - mode: '0755'
    - makedirs: True

homepage-settings.yaml:
  file.managed:
    - name: {{ homepage.config_dir }}/settings.yaml
    - source: salt://homepage/files/settings.yaml.j2
    - template: jinja
    - user: {{ homepage.puid }}
    - group: {{ homepage.pgid }}
    - mode: '0644'
    - require:
      - file: homepage-config-dir

homepage-services.yaml:
  file.managed:
    - name: {{ homepage.config_dir }}/services.yaml
    - source: salt://homepage/files/services.yaml.j2
    - template: jinja
    - user: {{ homepage.puid }}
    - group: {{ homepage.pgid }}
    - mode: '0644'
    - require:
      - file: homepage-config-dir
