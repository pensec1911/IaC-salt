base:
  '*':
    - GLOBAL

  'homepage':
    - homepage

  'monitoring':
    - grafana
    - prometheus

  'arrstack':
    - nfs-mount
    - arrstack

  # Per-minion pillar files as needed, e.g.:
  # 'jellyfin':
  #   - jellyfin
