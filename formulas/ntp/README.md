# ntp formula

Points `systemd-timesyncd` (Debian's default time client) at the NTP server(s) from pillar —
here the FRITZ!Box, for every minion. Writes a drop-in
`/etc/systemd/timesyncd.conf.d/salt.conf` (`NTP=`, `FallbackNTP=`), the shipped
`timesyncd.conf` stays untouched; restarts timesyncd on change.

**One source, no fallback** (`fallback_servers: []` clears Debian's `debian.pool.ntp.org`): if
the FRITZ!Box's clock is off, all VMs are off by the same amount and stay consistent with each
other (logs, TLS, Salt jobs); a VM can't drift onto a different source on its own. Per-link
servers from DHCP (systemd-networkd) are still used too — on this network that's the FRITZ!Box
again (its IPv6 address).

## Usage

```yaml
# salt/top.sls — every minion
'some-minion':
  - users
  - ntp
```

## Pillar

`pillar/ntp.sls` (all minions). Schema: `pillar.example.sls`.

## Checks

- `timedatectl timesync-status` — server in use, offset.
- Alerts in `pillar/prometheus.sls`: `ClockNotSynced` (`node_timex_sync_status == 0`),
  `ClockOffset` (|offset| > 0.5 s), both 15 min.
