{% from "alloy/map.jinja" import alloy with context %}

{%- if alloy.loki_url %}

include:
  - alloy.config

alloy-container:
  docker_container.running:
    - name: {{ alloy.container_name }}
    - image: {{ alloy.image }}:{{ alloy.tag }}
    - restart_policy: unless-stopped
    - binds:
      - {{ alloy.config_dir }}:/etc/alloy:ro
      - {{ alloy.data_dir }}:/var/lib/alloy/data:rw
      - {{ alloy.docker_socket }}:/var/run/docker.sock:ro
      - {{ alloy.journal_path }}:/var/log/journal:ro
      - /etc/machine-id:/etc/machine-id:ro
    - command:
      - run
      - /etc/alloy/config.alloy
      - --storage.path=/var/lib/alloy/data
    - require:
      - sls: docker
      - file: alloy-data-dir
      - file: alloy-config
    - watch:
      - file: alloy-config

{%- else %}

{#- No Loki in the mine yet (fresh setup, or this run renders before
   monitoring's loki.mine state). Visible in the run, nothing deployed. #}
alloy-waiting-for-loki:
  test.show_notification:
    - text: "No '{{ alloy.loki_mine_alias }}' entry in the Salt Mine yet — Alloy not deployed. Apply the Loki minion, then this one."

{%- endif %}
