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
