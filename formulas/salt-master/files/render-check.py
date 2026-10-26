#!/usr/bin/env python3
"""Render every minion's highstate from a checked-out tree, without touching the running master.

Run on salt-master by .githooks/pre-push (the only host with Salt), against a `git archive` of
the commit being pushed:

  render-check.py <tree>

Per minion ID in <tree>/salt/top.sls: `salt-call --local --id=<id> state.show_highstate` with
file_roots formulas/ + salt/ (the gitfs merge) and pillar_roots pillar/, in a throwaway config
dir. sdb is stubbed (every lookup returns a placeholder), so OpenBao isn't needed. On top of
the render itself:

  - requisites (require/watch/onchanges/… and their _in forms) must point at a state that
    exists in that minion's highstate — show_highstate alone doesn't check them;
  - no rendered value may still contain `sdb://` (a bare reference Salt never resolves).

Not covered: templates rendered at apply time (file.managed `template: jinja` sources) and
anything that depends on the minion's real grains — the master's own grains stand in.
Stdlib only.
"""
import concurrent.futures
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

SALT_CALL = "/usr/bin/salt-call"
TIMEOUT = 120
REQUISITES = ("require", "watch", "onchanges", "onfail", "prereq", "use", "listen")
REQ_KEYS = set(REQUISITES) | {r + "_in" for r in REQUISITES} | {r + "_any" for r in REQUISITES}

STUB_SDB = '''\
def get(key, profile=None):
    return "render-check-stub"
'''

MINION_CONF = """\
file_client: local
file_roots:
  base:
    - {tree}/formulas
    - {tree}/salt
pillar_roots:
  base:
    - {tree}/pillar
pillar_merge_lists: True
extension_modules: {ext}
cachedir: {work}/cache
pki_dir: {work}/pki
sock_dir: {work}/sock
log_file: {work}/log
osvault:
  driver: stub
"""


def minion_ids(tree):
    """Minion IDs targeted in salt/top.sls (quoted keys at env level, no globs)."""
    with open(os.path.join(tree, "salt", "top.sls")) as f:
        ids = re.findall(r"^  '([^']+)':", f.read(), re.M)
    return [i for i in ids if not re.search(r"[*?\[,]", i)]


def render(conf_dir, minion):
    proc = subprocess.run(
        [SALT_CALL, "-c", conf_dir, "--local", "--id=" + minion, "--out=json",
         "--log-level=error", "--retcode-passthrough", "state.show_highstate"],
        capture_output=True, text=True, timeout=TIMEOUT,
    )
    return proc.returncode, proc.stdout, proc.stderr


def without_tracebacks(text):
    """Salt's error lines, minus the Python tracebacks between them."""
    out, skipping = [], False
    for line in text.splitlines():
        if line.startswith("Traceback"):
            skipping = True
            continue
        if skipping:
            # A traceback ends with its unindented exception line ("SaltRenderError: …").
            if line and not line.startswith(" "):
                skipping = False
                out.append(line)
            continue
        out.append(line)
    return "\n".join(l for l in out if l.strip())


def requisite_errors(high):
    ids = set(high)
    by_type = {}   # module -> set of IDs and names
    sls_names = set()
    for sid, body in high.items():
        if not isinstance(body, dict):
            continue
        sls_names.add(body.get("__sls__", ""))
        for mod, args in body.items():
            if mod.startswith("__") or not isinstance(args, list):
                continue
            names = by_type.setdefault(mod.split(".")[0], set())
            names.add(sid)
            for arg in args:
                if isinstance(arg, dict) and "name" in arg:
                    names.add(str(arg["name"]))
                if isinstance(arg, dict) and "names" in arg:
                    names.update(str(n) if not isinstance(n, dict) else str(next(iter(n)))
                                 for n in arg["names"])

    def exists(kind, target):
        if any(c in target for c in "*?["):
            return True   # glob requisites match at apply time
        if kind == "sls":
            return any(s == target or s.startswith(target + ".") for s in sls_names)
        if kind == "id":
            return target in ids
        return target in by_type.get(kind, set())

    errors = []
    for sid, body in high.items():
        if not isinstance(body, dict):
            continue
        for mod, args in body.items():
            if mod.startswith("__") or not isinstance(args, list):
                continue
            for arg in args:
                if not isinstance(arg, dict):
                    continue
                for key, reqs in arg.items():
                    if key not in REQ_KEYS or not isinstance(reqs, list):
                        continue
                    for req in reqs:
                        if isinstance(req, dict):
                            (kind, target), = req.items()
                        else:
                            kind, target = "id", req
                        if not exists(kind, str(target)):
                            errors.append("{} ({}): {}: {}: {} — no such state".format(
                                sid, body.get("__sls__"), key, kind, target))
    return errors


def bare_sdb(high):
    found = []

    def walk(value, where):
        if isinstance(value, str) and "sdb://" in value:
            found.append(where)
        elif isinstance(value, dict):
            for k, v in value.items():
                walk(v, where)
        elif isinstance(value, list):
            for v in value:
                walk(v, where)

    for sid, body in high.items():
        walk(body, "{} ({})".format(sid, body.get("__sls__") if isinstance(body, dict) else "?"))
    return ["{}: bare sdb:// value — use salt['sdb.get'](…) | yaml_encode".format(w)
            for w in sorted(set(found))]


def check(work, tree, minion):
    """List of problems for one minion; empty = ok."""
    # Own config/cache dir per minion: parallel salt-calls sharing a cachedir
    # refuse to run ("state.show_highstate is running as PID …").
    conf_dir = os.path.join(work, minion, "conf")
    os.makedirs(conf_dir)
    with open(os.path.join(conf_dir, "minion"), "w") as f:
        f.write(MINION_CONF.format(tree=tree, work=os.path.join(work, minion),
                                   ext=os.path.join(work, "ext")))
    try:
        rc, out, err = render(conf_dir, minion)
    except subprocess.TimeoutExpired:
        return ["render timed out after {}s".format(TIMEOUT)]
    if rc != 0:
        return [without_tracebacks(err + "\n" + out) or "salt-call exit {}".format(rc)]
    try:
        high = json.loads(out)["local"]
    except (ValueError, KeyError) as e:
        return ["unparsable salt-call output ({}): {}".format(e, out[:500])]
    if not isinstance(high, dict):
        return [str(high)]
    return requisite_errors(high) + bare_sdb(high)


def main():
    tree = os.path.abspath(sys.argv[1])
    started = time.time()
    work = tempfile.mkdtemp(prefix="render-check.")
    try:
        os.makedirs(os.path.join(work, "ext", "sdb"))
        with open(os.path.join(work, "ext", "sdb", "stub.py"), "w") as f:
            f.write(STUB_SDB)

        minions = minion_ids(tree)
        with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
            results = dict(zip(minions, pool.map(lambda m: check(work, tree, m), minions)))
    finally:
        shutil.rmtree(work, ignore_errors=True)

    failed = {m: p for m, p in results.items() if p}
    for minion, problems in failed.items():
        print("render-check: {} FAILED".format(minion))
        for p in problems:
            print("  " + p.replace("\n", "\n  "))
    print("render-check: {}/{} minions ok ({:.0f}s)".format(
        len(minions) - len(failed), len(minions), time.time() - started))
    return 1 if failed or not minions else 0


if __name__ == "__main__":
    sys.exit(main())
