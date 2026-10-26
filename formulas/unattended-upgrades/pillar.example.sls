# Pillar for formulas/unattended-upgrades. Nothing is required — the
# defaults (unattended-upgrades/map.jinja) are what every minion runs.
unattended-upgrades:
  lookup:
    # Manual reboots by default (RebootRequired alert). If true, u-u reboots
    # at automatic_reboot_time after an upgrade that needs it.
    automatic_reboot: False
    automatic_reboot_time: "04:00"
    remove_unused_kernel_packages: True
    remove_unused_dependencies: False
    # Debian packages u-u must not touch (third-party repos are already
    # excluded by the shipped Origins-Pattern).
    package_blacklist: []
    dropin: /etc/apt/apt.conf.d/52unattended-upgrades-salt
    metrics:
      on_calendar: hourly
      on_boot: 2min
      textfile_dir: /var/lib/prometheus/node-exporter
      metrics_file: os_patch.prom
