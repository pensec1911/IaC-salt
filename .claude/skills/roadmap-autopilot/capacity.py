#!/usr/bin/env python3
"""Capacity check for the roadmap autopilot (read-only).

Per minion: RAM size, 7-day peak used, headroom to the 80 % ceiling, root disk free above the
5 GB floor, container host or not. Per Proxmox node: allocated memory_mb from the sibling
IaC-opentofu repo (active modules in vms.tf only) against the 14 GB allocation ceiling, with the
reservations from .claude/docs/capacity.md. Rules: .claude/docs/capacity.md.

    python3 .claude/skills/roadmap-autopilot/capacity.py
"""
import json
import pathlib
import re
import urllib.parse
import urllib.request

PROM = "http://192.168.178.25:9090/api/v1/query"
import subprocess  # noqa: E402
# Sibling repo next to the *main* checkout — from a worktree (.claude/worktrees/…) the file's own
# parents point inside IaC-salt, so go via git's common dir.
_COMMON = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                         cwd=pathlib.Path(__file__).parent, capture_output=True, text=True).stdout.strip()
TOFU = pathlib.Path(_COMMON).parent.parent / "IaC-opentofu"
RAM_CEILING = 0.80          # peak used + new services <= 80 % of the VM's RAM
DISK_FLOOR_GB = 5.0         # root fs keeps >= 5 GB free after the change
NODE_CEILING_MB = 14336     # 16 GB node minus ~2 GB for the PVE host itself
RESERVED_MB = {}   # node -> MB held back for planned VMs; none at the moment


def q(expr):
    url = PROM + "?" + urllib.parse.urlencode({"query": expr})
    with urllib.request.urlopen(url, timeout=15) as r:
        res = json.load(r)["data"]["result"]
    return {x["metric"].get("instance", ""): float(x["value"][1]) for x in res}


def top_formulas(top, minion):
    """Formulas listed under '<minion>': in salt/top.sls (Jinja lines ignored)."""
    out, inside = [], False
    for line in top.splitlines():
        if re.match(r"^  '[^']+':", line):
            inside = line.strip() == f"'{minion}':"
        elif inside:
            f = re.match(r"^\s+- (\S+)$", line)
            if f:
                out.append(f.group(1))
    return out


def minions():
    total = q("node_memory_MemTotal_bytes")
    peak = q("max_over_time((node_memory_MemTotal_bytes-node_memory_MemAvailable_bytes)[7d:10m])")
    disk = q('node_filesystem_avail_bytes{mountpoint="/"}')
    cores = q('count by(instance)(node_cpu_seconds_total{mode="idle"})')
    cpu = q('100*(1-avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[1d])))')
    top = (pathlib.Path(__file__).resolve().parents[3] / "salt/top.sls").read_text()
    print(f"{'minion':<12} {'RAM GB':>6} {'peak7d':>7} {'room@80%':>9} {'disk free':>9} "
          f"{'room>5GB':>8} {'cores':>5} {'cpu1d%':>6}  podman")
    for m in sorted(total):
        t, p, d = total[m] / 1e9, peak.get(m, 0) / 1e9, disk.get(m, 0) / 1e9
        podman = "podman" in top_formulas(top, m)
        print(f"{m:<12} {t:6.1f} {p:7.2f} {RAM_CEILING * t - p:9.2f} {d:9.1f} "
              f"{d - DISK_FLOOR_GB:8.1f} {int(cores.get(m, 0)):5d} {cpu.get(m, 0):6.1f}  "
              f"{'yes' if podman else 'no'}")


def nodes():
    vms_tf = (TOFU / "vms.tf").read_text()
    active = re.findall(r'^module\s+"[^"]+"\s*{\s*\n\s*source\s*=\s*"\./vms/([^"]+)"', vms_tf, re.M)
    # VMs Tofu doesn't create but that run anyway (netbox.tf `netbox_unmanaged_vms`); size from
    # their vms/<name>/main.tf, node from netbox.tf (more current than the dormant module).
    unmanaged = re.findall(r'^\s+([\w-]+)\s*=\s*{\s*ip\s*=\s*"[^"]+",\s*node\s*=\s*"([^"]+)"',
                           (TOFU / "netbox.tf").read_text(), re.M)
    alloc = {}
    for vm, node in unmanaged:
        main = (TOFU / "vms" / vm / "main.tf").read_text()
        mem = int(re.search(r"memory_mb\s*=\s*(\d+)", main).group(1))
        alloc.setdefault(node, []).append((vm + "*", mem))
    for vm in active:
        main = (TOFU / "vms" / vm / "main.tf").read_text()
        node = re.search(r'node\s*=\s*"([^"]+)"', main).group(1)
        mem = int(re.search(r"memory_mb\s*=\s*(\d+)", main).group(1))
        alloc.setdefault(node, []).append((vm, mem))
    print(f"\n{'node':<6} {'alloc MB':>8} {'reserved':>8} {'free to 14GB':>12}  VMs")
    for node in sorted(set(alloc) | set(RESERVED_MB)):
        used = sum(m for _, m in alloc.get(node, []))
        res = RESERVED_MB.get(node, 0)
        vms = ", ".join(f"{v} {m // 1024}G" for v, m in alloc.get(node, []))
        print(f"{node:<6} {used:8d} {res:8d} {NODE_CEILING_MB - used - res:12d}  {vms}")
    print("* = not managed by Tofu (netbox.tf netbox_unmanaged_vms)")


if __name__ == "__main__":
    minions()
    nodes()
