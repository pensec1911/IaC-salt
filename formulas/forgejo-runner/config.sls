{% from "forgejo-runner/map.jinja" import runner with context %}

{%- if not runner.secret_valid %}
forgejo-runner-secret-invalid:
  test.fail_without_changes:
    - name: forgejo-runner:lookup:secret must be 40 lowercase hex chars (openssl rand -hex 20)
{%- else %}

forgejo-runner-data-dir:
  file.directory:
    - name: {{ runner.data_dir }}
    - user: {{ runner.uid }}
    - group: {{ runner.gid }}
    - mode: '0700'
    - makedirs: True
    - require:
      - user: user-forgejo-runner

{#- Docker's own state inside dind (pulled job images, build cache) —
   disposable, root-owned like any /var/lib/docker. #}
forgejo-runner-dind-dir:
  file.directory:
    - name: {{ runner.dind_dir }}
    - user: root
    - group: root
    - mode: '0710'
    - makedirs: True

forgejo-runner-config:
  file.managed:
    - name: {{ runner.data_dir }}/config.yml
    - source: salt://forgejo-runner/files/config.yml.j2
    - template: jinja
    - user: {{ runner.uid }}
    - group: {{ runner.gid }}
    - mode: '0600'
    - require:
      - file: forgejo-runner-data-dir

{#- The registration secret is the runner's token (read via token_url), so
   it's kept out of config.yml and the diff. #}
forgejo-runner-token:
  file.managed:
    - name: {{ runner.data_dir }}/token
    - contents: {{ runner.secret | yaml_encode }}
    - user: {{ runner.uid }}
    - group: {{ runner.gid }}
    - mode: '0600'
    - show_changes: False
    - require:
      - file: forgejo-runner-data-dir
{%- endif %}
