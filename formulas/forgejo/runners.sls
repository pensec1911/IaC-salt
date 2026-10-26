{% from "forgejo/map.jinja" import forgejo with context %}

include:
  - forgejo.container

{#- The secret goes in via the environment (docker exec -e S takes the
   value from the calling shell), never on a command line or in the state
   output. The marker holds only its sha256. #}
{%- for name, r in forgejo.runners | dictsort %}
{%-   set marker = forgejo.data_dir ~ '/.runner-registered-' ~ name %}
{%-   if (r.get('secret') or '') | regex_match('^([0-9a-f]{40})$') is none %}

forgejo-runner-register-{{ name }}:
  test.fail_without_changes:
    - name: forgejo:lookup:runners:{{ name }}:secret must be 40 lowercase hex chars (openssl rand -hex 20)
{%-   else %}

forgejo-runner-register-{{ name }}:
  cmd.run:
    - name: >-
        docker exec -e S {{ forgejo.container_name }}
        sh -c 'forgejo forgejo-cli actions register --name "$0" --scope "$1" --secret "$S"'
        {{ name | yaml_encode }} {{ r.get('scope', '') | yaml_encode }}
        && printf %s "$S" | sha256sum > {{ marker }}
    - unless: test -f {{ marker }} && printf %s "$S" | sha256sum | cmp -s - {{ marker }}
    {#- Before the install wizard there's no DB to register into. #}
    - onlyif: grep -Eq '^INSTALL_LOCK *= *true' {{ forgejo.data_dir }}/custom/conf/app.ini
    - env:
      - S: {{ r.secret | yaml_encode }}
    - require:
      - docker_container: forgejo-container
{%-   endif %}
{%- endfor %}
