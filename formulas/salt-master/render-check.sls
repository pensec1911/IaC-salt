{% from "salt-master/map.jinja" import salt_master with context %}

{% if salt_master.render_check_ci %}
render-check-script:
  file.managed:
    - name: {{ salt_master.render_check_script }}
    - source: salt://salt-master/files/render-check.py
    - makedirs: True
    - mode: '0755'

render-check-wrapper:
  file.managed:
    - name: {{ salt_master.render_check_wrapper }}
    - source: salt://salt-master/files/render-check-ci.j2
    - template: jinja
    - mode: '0755'
    - require:
      - file: render-check-script
{% else %}
render-check-wrapper:
  file.absent:
    - name: {{ salt_master.render_check_wrapper }}

render-check-script:
  file.absent:
    - name: {{ salt_master.render_check_script }}
{% endif %}
