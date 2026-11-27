{#- formulas/backup — nightly restic run per minion into its own repo
   /mnt/backups/<minion> on the NAS (export /mnt/pool01/backups). Only data
   Salt can't rebuild: app config/DBs under /opt, wazuh's keys and certs.
   Images and Salt-rendered config are reproducible and stay out; so do
   logs, caches and Prometheus/Loki data (rebuilt from scratch is fine) —
   e.g. recyclarr/resources, the TRaSH Guides clones (~75 MB) recyclarr
   re-fetches on every run.

   stop_containers: every container with a SQLite DB in the backed-up
   paths. arrstack: gluetun and flaresolverr keep running — the attached
   apps stop and start inside gluetun's network namespace, which stays.

   dumps: server DBs (Postgres) are dumped before the run instead of
   copying their live data dir, which is excluded (netbox/patchmon: the
   dump lands in /opt/<service>/dump; secrets come from OpenBao, valkey is only a queue/
   cache). The dumped container keeps running. #}
{#- salt-master: /var/backups/openbao is OpenBao's Raft snapshot
   (formulas/openbao-snapshot, 01:30, before this run). #}
{%- set per_minion = {
    'arrstack': {
        'paths': ['/opt/arrstack', '/opt/seerr'],
        'excludes': [
            '/opt/arrstack/gluetun',
            '/opt/arrstack/*/logs',
            '/opt/arrstack/*/logs.db*',
            '/opt/arrstack/*/MediaCover',
            '/opt/arrstack/recyclarr/resources',
            '/opt/seerr/config/logs',
        ],
        'stop_containers': ['sonarr', 'radarr', 'prowlarr', 'bazarr', 'qbittorrent', 'slskd', 'seerr'],
    },
    'forgejo': {
        'paths': ['/opt/forgejo', '/opt/netbox', '/opt/patchmon', '/opt/tofu-state'],
        'excludes': [
            '/opt/forgejo/data/tmp',
            '/opt/forgejo/data/repo-archive',
            '/opt/netbox/postgres',
            '/opt/netbox/valkey',
            '/opt/netbox/secrets',
            '/opt/patchmon/postgres',
            '/opt/patchmon/valkey',
            '/opt/patchmon/secrets',
            '/opt/tofu-state/postgres',
            '/opt/tofu-state/secrets',
        ],
        'stop_containers': ['forgejo'],
        'dumps': [
            {'container': 'netbox-postgres',
             'command': ['pg_dump', '-U', 'netbox', '-Fc', 'netbox'],
             'file': '/opt/netbox/dump/netbox.pgdump',
             'format': 'pg_custom'},
            {'container': 'patchmon-postgres',
             'command': ['pg_dump', '-U', 'patchmon_user', '-Fc', 'patchmon_db'],
             'file': '/opt/patchmon/dump/patchmon.pgdump',
             'format': 'pg_custom'},
            {'container': 'tofu-state-postgres',
             'command': ['pg_dump', '-U', 'tofu', '-Fc', 'tofu'],
             'file': '/opt/tofu-state/dump/tofu.pgdump',
             'format': 'pg_custom'},
        ],
    },
    'jellyfin': {
        'paths': ['/opt/jellyfin', '/opt/ntfy', '/opt/healthchecks'],
        'excludes': [
            '/opt/jellyfin/config/cache',
            '/opt/jellyfin/config/log',
            '/opt/ntfy/config',
            '/opt/healthchecks/provision',
        ],
        'stop_containers': ['jellyfin', 'ntfy', 'healthchecks'],
    },
    'monitoring': {
        'paths': ['/opt/grafana/data', '/opt/alertmanager/data'],
        'excludes': [],
        'stop_containers': ['grafana'],
    },
    'cloud-edge': {
        'paths': ['/opt/headscale/data'],
        'excludes': [],
        'stop_containers': ['headscale'],
    },
    'edge': {
        'paths': ['/opt/caddy/data', '/opt/authentik'],
        'excludes': [
            '/opt/authentik/postgres',
            '/opt/authentik/secrets',
            '/opt/authentik/blueprints',
        ],
        'stop_containers': [],
        'dumps': [
            {'container': 'authentik-postgres',
             'command': ['pg_dump', '-U', 'authentik', '-Fc', 'authentik'],
             'file': '/opt/authentik/dump/authentik.pgdump',
             'format': 'pg_custom'},
        ],
    },
    'docs': {
        'paths': ['/opt/paperless'],
        'excludes': [
            '/opt/paperless/postgres',
            '/opt/paperless/valkey',
            '/opt/paperless/secrets',
            '/opt/paperless/data/log',
            '/opt/paperless/data/celerybeat-schedule*',
        ],
        'stop_containers': [],
        'dumps': [
            {'container': 'paperless-postgres',
             'command': ['pg_dump', '-U', 'paperless', '-Fc', 'paperless'],
             'file': '/opt/paperless/dump/paperless.pgdump',
             'format': 'pg_custom'},
        ],
    },
    'salt-master': {
        'paths': ['/etc/salt/pki/master', '/etc/salt/pki/api', '/var/backups/openbao'],
        'excludes': [],
        'stop_containers': [],
    },
    'gateway': {
        'paths': ['/var/lib/tailscale'],
        'excludes': [],
        'stop_containers': [],
    },
    'wazuh': {
        'paths': [
            '/var/ossec/etc',
            '/var/ossec/api/configuration',
            '/etc/wazuh-indexer/certs',
            '/etc/wazuh-indexer/opensearch-security',
            '/etc/wazuh-dashboard/certs',
            '/etc/filebeat/certs',
            '/root/wazuh-certificates.tar',
        ],
        'excludes': [],
        'stop_containers': [],
    },
} %}
{#- Own repo passwords where the shared one would be too wide (all repos sit
   on the same rw NAS export):
   - cloud-edge sits outside the house (OCI), so a compromised cloud-edge
     can't open the other minions' repos.
   - salt-master's repo holds the master key (pki/master): with the shared
     password any minion could read it and impersonate the master to all
     of them. Its AppRole secret_id stays out (regenerable, README). #}
{%- set password_path = {
    'cloud-edge': 'restic/cloud-edge',
    'salt-master': 'restic/salt-master',
}.get(grains['id'], 'restic/repo') %}
{%- set this = per_minion.get(grains['id'], {'paths': [], 'excludes': [], 'stop_containers': [], 'dumps': []}) %}

backup:
  lookup:
    password: {{ salt['sdb.get']('sdb://osvault/homelab/data/' ~ password_path ~ '?password') | yaml_encode }}
    paths: {{ this.paths | json }}
    excludes: {{ this.excludes | json }}
    stop_containers: {{ this.stop_containers | json }}
    dumps: {{ this.get('dumps', []) | json }}

# Appended to the minion's other mounts (pillar_merge_lists). No container
# binds it: skip_required_by keeps it out of nfs-mount's required_by units,
# nofail keeps a refused export from failing the boot.
# The backup unit has its own RequiresMountsFor=.
nfs_mounts:
  - name: backups
    server: 192.168.178.10
    export: /mnt/pool01/backups
    mountpoint: /mnt/backups
    opts:
      - _netdev
      - rw
      - noatime
      - nofail
    skip_required_by: true
