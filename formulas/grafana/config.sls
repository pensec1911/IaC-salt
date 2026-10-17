{% from "grafana/map.jinja" import grafana with context %}
{%- set dashboards = salt['pillar.get']('grafana:dashboards', []) %}

grafana-data-dir:
  file.directory:
    - name: {{ grafana.data_dir }}
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0755'
    - makedirs: True

{#- Only the datasources/ and dashboards/ subdirs are bind-mounted (see
   container.sls), so the image's other provisioning dirs stay intact.
   Grafana reads provisioning/ only at startup → container.sls watches
   these two files. Dashboard JSON is re-read by the provider on its own
   (updateIntervalSeconds), no restart needed. #}
grafana-datasources:
  file.managed:
    - name: {{ grafana.provisioning_dir }}/datasources/salt.yaml
    - source: salt://grafana/files/datasources.yaml.j2
    - template: jinja
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0644'
    - makedirs: True

grafana-dashboard-provider:
  file.managed:
    - name: {{ grafana.provisioning_dir }}/dashboards/salt.yaml
    - source: salt://grafana/files/dashboards.yaml.j2
    - template: jinja
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0644'
    - makedirs: True

grafana-dashboards-dir:
  file.directory:
    - name: {{ grafana.dashboards_dir }}
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0755'
    - makedirs: True
    # Drops dashboards removed from pillar.
    - clean: True
{%- if dashboards %}
    - require:
{%- for d in dashboards %}
      - file: grafana-dashboard-{{ d.name }}
{%- endfor %}
{%- endif %}

{#- Pinned grafana.com revision + sha256, so a changed upstream file fails
   the state instead of silently changing the dashboard. #}
{%- for d in dashboards %}
grafana-dashboard-{{ d.name }}:
  file.managed:
    - name: {{ grafana.dashboards_dir }}/{{ d.name }}.json
    - source: {{ grafana.dashboards_source.format(id=d.gnet_id, revision=d.revision) }}
    - source_hash: sha256={{ d.sha256 }}
    - user: {{ grafana.uid }}
    - group: {{ grafana.gid }}
    - mode: '0644'
    - makedirs: True
{%- endfor %}
