{% from "forgejo/map.jinja" import forgejo with context %}

{#- Local disk: the bare repos, the SQLite DB and custom/conf/app.ini (incl.
   the secrets the first-run wizard generated) all live under data_dir. #}
forgejo-data-dir:
  file.directory:
    - name: {{ forgejo.data_dir }}
    - user: {{ forgejo.uid }}
    - group: {{ forgejo.gid }}
    - mode: '0750'
    - makedirs: True
    - require:
      - user: user-git
{%- if forgejo.extra_ca_certs %}

forgejo-ca-dir:
  file.directory:
    - name: {{ forgejo.ca_dir }}
    - user: root
    - group: root
    - mode: '0755'
    - makedirs: True
{%- for name, pem in forgejo.extra_ca_certs | dictsort %}

forgejo-ca-{{ name }}:
  file.managed:
    - name: {{ forgejo.ca_dir }}/{{ name }}.crt
    - contents: {{ pem | yaml_encode }}
    - mode: '0644'
    - require:
      - file: forgejo-ca-dir
    - require_in:
      - docker_container: forgejo-container
{%- endfor %}
{%- endif %}
