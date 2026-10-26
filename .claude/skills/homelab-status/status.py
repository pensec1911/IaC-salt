#!/usr/bin/env python3
"""Read-only homelab health summary from Prometheus + Alertmanager on monitoring.

Usage: python3 .claude/skills/homelab-status/status.py [minion]
Prints firing alerts, then one row per minion (drift, backup, restore test,
patches), then failed probes. Exit 1 if anything needs attention.
"""
import json
import sys
import time
import urllib.parse
import urllib.request

PROM = "http://192.168.178.25:9090"
AM = "http://192.168.178.25:9093"
NOW = time.time()


def get(url):
    with urllib.request.urlopen(url, timeout=10) as r:
        return json.load(r)


def query(expr):
    url = f"{PROM}/api/v1/query?" + urllib.parse.urlencode({"query": expr})
    return {
        s["metric"].get("instance", "?"): float(s["value"][1])
        for s in get(url)["data"]["result"]
    }


def age(ts):
    if not ts:
        return "never"
    h = (NOW - ts) / 3600
    return f"{h:.0f}h" if h < 48 else f"{h / 24:.0f}d"


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    bad = False

    try:
        alerts = get(f"{AM}/api/v2/alerts?active=true&silenced=false&inhibited=false")
    except OSError as e:
        print(f"Alertmanager unreachable: {e}")
        return 2
    alerts = [a for a in alerts if not only or a["labels"].get("instance") == only]
    print(f"== Firing alerts: {len(alerts)}")
    for a in sorted(alerts, key=lambda a: a["labels"].get("severity", "")):
        l = a["labels"]
        summary = a.get("annotations", {}).get("summary", "")
        print(f"  [{l.get('severity', '-')}] {l.get('alertname')} {l.get('instance', '')} {summary}")
    bad |= bool(alerts)

    up = query('up{job="node"}')
    pending = query("salt_drift_states_pending")
    failed = query("salt_drift_states_failed")
    drift_ok = query("salt_drift_check_success")
    bk_ok = query("backup_success")
    bk_last = query("backup_last_success_timestamp_seconds")
    rt_ok = query("restore_test_success")
    rt_last = query("restore_test_last_success_timestamp_seconds")
    reboot = query("os_reboot_required")
    sec = query("os_security_upgrades_pending")

    print("\n== Minions")
    print(f"  {'minion':<12} {'up':<3} {'drift':<14} {'backup':<10} {'restore':<10} patches")
    for m in sorted(up):
        if only and m != only:
            continue
        drift = "check-fail" if drift_ok.get(m) == 0 else (
            f"{pending.get(m, 0):.0f}p/{failed.get(m, 0):.0f}f"
            if pending.get(m) or failed.get(m) else "clean")
        bk = "-" if m not in bk_ok else (
            ("ok " if bk_ok[m] else "FAIL ") + age(bk_last.get(m)))
        rt = "-" if m not in rt_ok else (
            ("ok " if rt_ok[m] else "FAIL ") + age(rt_last.get(m)))
        pt = []
        if sec.get(m):
            pt.append(f"{sec[m]:.0f} security")
        if reboot.get(m):
            pt.append("reboot")
        print(f"  {m:<12} {'y' if up[m] else 'N':<3} {drift:<14} {bk:<10} {rt:<10} {', '.join(pt) or 'ok'}")
        bad |= not up[m] or drift != "clean" or "FAIL" in bk + rt

    if not only:
        probes = get(f"{PROM}/api/v1/query?" + urllib.parse.urlencode(
            {"query": "probe_success == 0"}))["data"]["result"]
        print(f"\n== Failed UI probes: {len(probes)}")
        for p in probes:
            print(f"  {p['metric'].get('instance')} {p['metric'].get('url')}")
        bad |= bool(probes)

    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
