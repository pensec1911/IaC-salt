# Self-repair at night only (formulas/salt-minion drift check, enforce with
# a window) for the minions listed under this file in pillar/top.sls. A
# repair can recreate containers — cuts Jellyfin streams, restarts
# arrstack's VPN stack — so it waits for 03:00–06:00 Berlin time (three
# hourly runs). During the day they only report, like before. Consequence:
# a push reaches them the following night.
salt-minion:
  lookup:
    drift_check:
      enforce: True
      enforce_window:
        start: "03:00"
        end: "06:00"
        timezone: Europe/Berlin
