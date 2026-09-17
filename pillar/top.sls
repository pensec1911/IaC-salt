base:
  '*':
    - GLOBAL

  'homepage':
    - homepage

  'monitoring':
    - grafana
    - prometheus

  # Per-minion pillar files as needed, e.g.:
  # 'jellyfin':
  #   - jellyfin
