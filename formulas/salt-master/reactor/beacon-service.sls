{#- Reactor SLS (not a state) — wired up in /etc/salt/master.d/reactor.conf
   by formulas/salt-master. Fired by a minion's service beacon
   (formulas/salt-minion) on salt/beacon/<id>/service/<name>; `data` is
   {<name>: {running: bool}, service_name: <name>, id: <id>}.

   Only acts on running: False and only for services whitelisted in master
   opts (reactor.conf) — the event names the service, the master decides.
   Unlike salt/minion/<id>/start, the master doesn't check a beacon event's
   `id` against the sender, so a minion could name another one; the worst
   that does is start a whitelisted service there.

   service.start, not a highstate: arrstack/jellyfin are report-only (a
   highstate there may recreate containers); starting a stopped service
   cuts nothing that isn't down already. #}
{%- set allowed = opts.get('homelab_beacon_restart_services', []) %}
{%- set name = data.get('service_name') %}
{%- if name in allowed and data.get(name, {}).get('running') is sameas false %}
start-stopped-service:
  local.service.start:
    - tgt: {{ data['id'] | yaml_encode }}
    - args:
      - name: {{ name | yaml_encode }}
{%- endif %}
