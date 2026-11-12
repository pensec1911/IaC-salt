{% from "alloy/map.jinja" import alloy with context %}
{% from "podman/macros.jinja" import container with context %}

{%- if alloy.loki_url %}

include:
  - alloy.config

{#- Root inside, a sub-UID on the host. Reads the journal through the host's
   systemd-journal group, mapped 1:1 into the container (journal_gid) and
   added as a supplementary group. data_dir: :U hands it to the container's
   root (map.jinja); bound outside the image's /var/lib/alloy, which is
   0770 for uid 473 — root without DAC_OVERRIDE can't get through it. #}
{%- set spec = {
    'name': alloy.container_name,
    'image': alloy.image,
    'tag': alloy.tag,
    'keep_gids': [alloy.journal_gid],
    'group_add': [alloy.journal_gid],
    'volumes': [
        alloy.config_dir ~ ':/etc/alloy:ro',
        alloy.data_dir ~ ':/alloy-data:U',
        alloy.journal_path ~ ':/var/log/journal:ro',
        '/etc/machine-id:/etc/machine-id:ro',
    ],
    'command': ['run', '/etc/alloy/config.alloy', '--storage.path=/alloy-data'],
} %}
{%- do spec.update(alloy.podman) %}
{{ container('alloy-container', spec,
             require=[{'file': 'alloy-data-dir'}, {'file': 'alloy-config'}],
             watch=[{'file': 'alloy-config'}]) }}

{%- else %}

{#- No Loki in the mine yet (fresh setup, or this run renders before
   monitoring's loki.mine state). Visible in the run, nothing deployed. #}
alloy-waiting-for-loki:
  test.show_notification:
    - text: "No '{{ alloy.loki_mine_alias }}' entry in the Salt Mine yet — Alloy not deployed. Apply the Loki minion, then this one."

{%- endif %}
