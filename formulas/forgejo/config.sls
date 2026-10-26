{% from "forgejo/map.jinja" import forgejo with context %}

{#- Local disk: data holds the bare repos and the SQLite DB, config holds
   app.ini incl. the secrets the first-run wizard generated. #}
{%- for name, path in [('data', forgejo.data_dir), ('config', forgejo.config_dir)] %}

forgejo-{{ name }}-dir:
  file.directory:
    - name: {{ path }}
    - user: {{ forgejo.uid }}
    - group: {{ forgejo.gid }}
    - mode: '0750'
    - makedirs: True
    - require:
      - user: user-git
{%- endfor %}
