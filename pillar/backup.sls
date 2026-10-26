{#- formulas/backup — nightly restic run per minion into its own repo
   /mnt/backups/<minion> on the NAS (export /mnt/pool01/backups). Only data
   Salt can't rebuild: app config/DBs under /opt, wazuh's keys and certs.
   Images and Salt-rendered config are reproducible and stay out; so do
   logs, caches and Prometheus/Loki data (rebuilt from scratch is fine).

   stop_containers: every container with a SQLite DB in the backed-up
   paths. arrstack: gluetun and flaresolverr keep running — the attached
   apps stop and start inside gluetun's network namespace, which stays. #}
{%- set per_minion = {
    'arrstack': {
        'paths': ['/opt/arrstack', '/opt/seerr'],
        'excludes': [
            '/opt/arrstack/gluetun',
            '/opt/arrstack/*/logs',
            '/opt/arrstack/*/logs.db*',
            '/opt/arrstack/*/MediaCover',
            '/opt/seerr/config/logs',
        ],
        'stop_containers': ['sonarr', 'radarr', 'prowlarr', 'bazarr', 'qbittorrent', 'slskd', 'seerr'],
    },
    'jellyfin': {
        'paths': ['/opt/jellyfin'],
        'excludes': ['/opt/jellyfin/config/cache', '/opt/jellyfin/config/log'],
        'stop_containers': ['jellyfin'],
    },
    'monitoring': {
        'paths': ['/opt/grafana/data', '/opt/alertmanager/data'],
        'excludes': [],
        'stop_containers': ['grafana'],
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
{%- set this = per_minion.get(grains['id'], {'paths': [], 'excludes': [], 'stop_containers': []}) %}

backup:
  lookup:
    password: {{ salt['sdb.get']('sdb://osvault/homelab/data/restic/repo?password') | yaml_encode }}
    paths: {{ this.paths | json }}
    excludes: {{ this.excludes | json }}
    stop_containers: {{ this.stop_containers | json }}

# Appended to the minion's other mounts (pillar_merge_lists). No container
# binds it: skip_required_by keeps it out of docker's RequiresMountsFor= on
# arrstack/jellyfin, nofail keeps a refused export from failing the boot.
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
