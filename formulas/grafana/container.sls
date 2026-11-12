{% from "grafana/map.jinja" import grafana with context %}
{% from "podman/macros.jinja" import container with context %}

include:
  - grafana.config

{#- uid/gid mapped 1:1: data and provisioning dirs stay owned by them on the
   host. The admin password goes through the 0600 secret env file, not the
   unit. #}
{%- set spec = {
    'name': grafana.container_name,
    'image': grafana.image,
    'tag': grafana.tag,
    'user': grafana.uid ~ ':' ~ grafana.gid,
    'keep_uids': [grafana.uid],
    'keep_gids': [grafana.gid],
    'ports': [grafana.host_port ~ ':3000'],
    'volumes': [
        grafana.data_dir ~ ':/var/lib/grafana:rw',
        grafana.provisioning_dir ~ '/datasources:/etc/grafana/provisioning/datasources:ro',
        grafana.provisioning_dir ~ '/dashboards:/etc/grafana/provisioning/dashboards:ro',
        grafana.dashboards_dir ~ ':/var/lib/grafana-dashboards:ro',
    ],
    'env': grafana.env,
    'secret_env': {'GF_SECURITY_ADMIN_USER': grafana.admin_user},
} %}
{%- do spec.secret_env.update({'GF_SECURITY_ADMIN_PASSWORD': grafana.admin_password}) %}{#- secret-scan: allow (variable, not a value) #}
{%- do spec.update(grafana.podman) %}
{%- set files = [{'file': 'grafana-datasources'}, {'file': 'grafana-dashboard-provider'}] %}
{{ container('grafana-container', spec,
             require=[{'file': 'grafana-data-dir'}, {'file': 'grafana-dashboards-dir'}] + files,
             watch=files) }}
