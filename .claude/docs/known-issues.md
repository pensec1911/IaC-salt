# Known issues / open work

Remove an entry once fixed (the fix lives in git history).

## Smaller items

- arrstack is on the latest release *within* each major (2026-10-17). Newer majors exist and
  were deliberately not taken: Radarr 6, Prowlarr 2, qBittorrent 5 — each migrates its config/DB
  one-way, so back up `/opt/arrstack/<app>` and read the release notes before bumping.
