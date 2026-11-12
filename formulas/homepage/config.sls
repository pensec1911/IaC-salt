{% from "homepage/map.jinja" import homepage with context %}

{#- root-owned and only read by the container (bound read-only, map.jinja
   tmpfs) — the container's uid is a sub-UID on the host, so nothing it
   owns flips with Salt's ownership here. #}
homepage-config-dir:
  file.directory:
    - name: {{ homepage.config_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True

{%- for name in ['settings', 'services'] %}

homepage-{{ name }}.yaml:
  file.managed:
    - name: {{ homepage.config_dir }}/{{ name }}.yaml
    - source: salt://homepage/files/{{ name }}.yaml.j2
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - file: homepage-config-dir
{%- endfor %}
