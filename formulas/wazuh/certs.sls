{% from "wazuh/map.jinja" import wazuh with context %}

include:
  - wazuh.install

{#- Certs are GENERATED manually (README "Bootstrap" step 2 — never by Salt)
   into certs_tar. Salt only unpacks them into each component's dir with the
   names, modes and owners from Wazuh's step-by-step guide. `creates` makes
   this one-time: replacing certs later means deleting the dir first. #}
wazuh-certs-tar-present:
  file.exists:
    - name: {{ wazuh.certs_tar }}

{%- set components = [
    ('indexer',   wazuh.indexer.certs_dir,   wazuh.indexer.node_name,   'indexer',   'wazuh-indexer',   ['admin.pem', 'admin-key.pem'], 'wazuh-indexer-package'),
    ('filebeat',  wazuh.filebeat.certs_dir,  wazuh.manager.node_name,   'filebeat',  'root',            [],                             'filebeat-package'),
    ('dashboard', wazuh.dashboard.certs_dir, wazuh.dashboard.node_name, 'dashboard', 'wazuh-dashboard', [],                             'wazuh-dashboard-package'),
] %}
{%- for name, dir, node, target, owner, extra, pkg in components %}

wazuh-{{ name }}-certs:
  cmd.run:
    - name: >-
        set -e;
        mkdir -p {{ dir }};
        tar -xf {{ wazuh.certs_tar }} -C {{ dir }} ./{{ node }}.pem ./{{ node }}-key.pem ./root-ca.pem {% for f in extra %}./{{ f }} {% endfor %};
        {%- if node != target %}
        mv -n {{ dir }}/{{ node }}.pem {{ dir }}/{{ target }}.pem;
        mv -n {{ dir }}/{{ node }}-key.pem {{ dir }}/{{ target }}-key.pem;
        {%- endif %}
        chmod 500 {{ dir }};
        chmod 400 {{ dir }}/*;
        chown -R {{ owner }}:{{ owner }} {{ dir }}
    - shell: /bin/bash
    - creates: {{ dir }}/{{ target }}.pem
    - require:
      - file: wazuh-certs-tar-present
      - pkg: {{ pkg }}
{%- endfor %}
