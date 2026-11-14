{#- Reconnect hardening: minion.d options, heartbeat schedule and a systemd
   watchdog that restarts a salt-minion stuck without its master.
   Mechanics: map.jinja "reconnect". #}
{% from "salt-minion/map.jinja" import salt_minion with context %}
{%- set rc = salt_minion.reconnect %}
{%- set wd = rc.watchdog %}
{%- set ctx = {'rc': rc, 'wd': wd,
               'proc_dir': salt_minion.version.upgrade.proc_dir,
               'upgrade_unit': salt_minion.version.upgrade.unit} %}

{%- if rc.enabled %}

salt-minion-watchdog-script:
  file.managed:
    - name: {{ wd.script }}
    - source: salt://salt-minion/files/salt-minion-watchdog.sh.j2
    - template: jinja
    - mode: '0755'
    - context: {{ ctx | json }}

salt-minion-reconnect-conf:
  file.serialize:
    - name: {{ rc.conf_file }}
    - dataset: {{ rc.options | json }}
    - serializer: yaml
    - mode: '0644'

{#- Restart once the minion is idle, from outside its cgroup. #}
salt-minion-reconnect-restart:
  cmd.run:
    - name: >-
        systemd-run --unit={{ wd.restart_unit }} --collect
        --description="salt-minion restart after config change"
        --on-active={{ wd.restart_delay_seconds }}s
        {{ wd.script }} --restart-when-idle
    - unless: systemctl is-active --quiet {{ wd.restart_unit }}.timer || systemctl is-active --quiet {{ wd.restart_unit }}.service
    - onchanges:
      - file: salt-minion-reconnect-conf
    - require:
      - file: salt-minion-watchdog-script

{#- Persisted to _schedule.conf like drift-check. Runs in the minion's own
   loop, so a stale file means that loop is dead. #}
salt-minion-heartbeat-schedule:
  schedule.present:
    - name: heartbeat
    - function: file.touch
    - job_args:
      - {{ rc.heartbeat_file }}
    - minutes: {{ rc.heartbeat_minutes }}
    - return_job: False

salt-minion-watchdog-service:
  file.managed:
    - name: /etc/systemd/system/{{ wd.unit }}.service
    - contents: |
        # Managed by Salt (formulas/salt-minion reconnect.sls) — do not edit.
        [Unit]
        Description=Restart salt-minion when it lost its master for good
        [Service]
        Type=oneshot
        ExecStart={{ wd.script }}

salt-minion-watchdog-timer:
  file.managed:
    - name: /etc/systemd/system/{{ wd.unit }}.timer
    - contents: |
        # Managed by Salt (formulas/salt-minion reconnect.sls) — do not edit.
        [Unit]
        Description=salt-minion watchdog every {{ wd.interval }}
        [Timer]
        OnBootSec={{ wd.interval }}
        OnUnitActiveSec={{ wd.interval }}
        [Install]
        WantedBy=timers.target

salt-minion-watchdog-reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: salt-minion-watchdog-service
      - file: salt-minion-watchdog-timer

salt-minion-watchdog-timer-running:
  service.running:
    - name: {{ wd.unit }}.timer
    - enable: True
    - require:
      - cmd: salt-minion-watchdog-reload
      - file: salt-minion-watchdog-script
    - watch:
      - file: salt-minion-watchdog-timer

{%- else %}

salt-minion-watchdog-timer-dead:
  service.dead:
    - name: {{ wd.unit }}.timer
    - enable: False

salt-minion-watchdog-files-absent:
  file.absent:
    - names:
      - /etc/systemd/system/{{ wd.unit }}.timer
      - /etc/systemd/system/{{ wd.unit }}.service
      - {{ wd.script }}
    - require:
      - service: salt-minion-watchdog-timer-dead

salt-minion-heartbeat-schedule:
  schedule.absent:
    - name: heartbeat

{#- conf_file is left in place: removing it would need a restart too. #}

{%- endif %}
