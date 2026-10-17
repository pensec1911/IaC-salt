#!/usr/bin/env python3
"""Block commits that would publish secrets or private data to GitHub.

Modes:
  check-secrets.py           scan what is staged (added lines + staged file names) — the pre-commit hook
  check-secrets.py --all     scan every tracked file (full audit)

A line can be exempted with a trailing `secret-scan: allow` comment — only for verified false
positives, never to push a real secret through. Stdlib only, no dependencies.
"""
import ipaddress
import re
import subprocess
import sys

# --- file names that must never be committed -------------------------------------------------
FORBIDDEN_NAMES = [
    (r"(^|/)\.env(\..*)?$", "dotenv file"),
    (r"\.(pem|key|p12|pfx|kdbx|ovpn)$", "key/cert/credential container"),
    (r"(^|/)id_(rsa|ed25519|ecdsa|dsa)(\.pub)?$", "SSH key"),
    (r"(^|/)vault-secret-id", "OpenBao AppRole secret_id"),
    (r"(^|/)wg[^/]*\.conf$|wireguard[^/]*\.conf$", "WireGuard config (contains PrivateKey)"),
    (r"(^|/)\.claude/settings\.local\.json$", "personal Claude settings"),
    (r"(^|/)todo/", "personal todo dir (gitignored on purpose)"),
]

# --- content patterns: always a finding ------------------------------------------------------
CONTENT_PATTERNS = [
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "private key block"),
    (r"(?<![A-Za-z0-9+/])[A-Za-z0-9+/]{42}[AEIMQUYcgkosw048]=(?![A-Za-z0-9+/=])", "32-byte base64 key (WireGuard etc.)"),
    (r"\$(6|5|y|2[aby])\$(?:[^\s$]*\$){1,2}[./A-Za-z0-9]{20,}", "password hash (crypt)"),
    (r"\bgh[pousr]_[A-Za-z0-9]{36,}\b|\bgithub_pat_[A-Za-z0-9_]{40,}\b", "GitHub token"),
    (r"\bhv[sbr]\.[A-Za-z0-9_-]{20,}\b", "Vault/OpenBao token"),
    (r"\bAKIA[0-9A-Z]{16}\b", "AWS access key"),
    (r"\bsk-(ant-)?[A-Za-z0-9_-]{20,}\b", "API key (sk-…)"),
    (r"\bxox[abprs]-[A-Za-z0-9-]{10,}\b", "Slack token"),
    (r"https?://[^/\s:@]+:[^/\s@]+@", "credentials in URL"),
]

# key = literal value  (YAML / ini / env / HCL style). Values that are references, templates,
# placeholders or empty are fine.
ASSIGNMENT = re.compile(
    r"""(?ix)
    (?P<key>[A-Za-z0-9_.-]*(password|passwd|passwort|kennwort|secret|token|api[_-]?key|private[_-]?key|secret[_-]?id|credential)s?)
    ['"]?\s*[:=]\s*
    (?P<val>[^\s#,}]+.*?)\s*(\#.*)?$
    """
)
SAFE_VALUE = re.compile(
    r"""(?x)^(
        ''|""|\[\]|\{\}|null|~|none|true|false|\d+     # empty / bool / numbers
      | ['"]?\{\{.*                                    # Jinja expression (sdb.get, pillar, …)
      | ['"]?\{%.*
      | ['"]?\$\{?[A-Za-z_].*                          # shell/env variable
      | ['"]?<[^>]+>['"]?                              # <placeholder>
      | ['"]?(\.\.\.|…|x+|\*+|changeme|redacted)['"]?  # obvious placeholders
      | ['"]?/[^\s]*['"]?                              # a file path, not a value
      | ['"]?sdb://.*                                  # reference (bare ones are caught by salt-reviewer)
      | salt\[.*
    )$"""
)

EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
EMAIL_ALLOW = re.compile(r"@(anthropic\.com|example\.(com|org)|users\.noreply\.github\.com)$|^git@github\.com$")
IPV4 = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{1,3}){3})(?![\d.])")
HOME_PATH = re.compile(r"/home/[a-z_][a-z0-9_-]*/|/Users/[A-Za-z]")

ALLOW_MARK = "secret-scan: allow"
TEXT_SKIP = re.compile(r"\.(png|jpe?g|gif|ico|svg|woff2?|ttf|pdf)$")


def git(*args):
    return subprocess.run(["git", *args], capture_output=True, text=True, check=True).stdout


def check_line(path, lineno, line, findings):
    if ALLOW_MARK in line:
        return
    for pat, what in CONTENT_PATTERNS:
        if re.search(pat, line):
            findings.append((path, lineno, what, line))
    m = ASSIGNMENT.search(line)
    if m:
        val = m.group("val").strip().rstrip(",")
        # In prose only a single bare token after the colon counts, not a sentence.
        prose_ok = not path.endswith(".md") or not re.search(r"[\s`]", val)
        if prose_ok and not SAFE_VALUE.match(val) and len(val.strip("'\"")) >= 6:
            findings.append((path, lineno, f"literal value for '{m.group('key')}'", line))
    for e in EMAIL.findall(line):
        if not EMAIL_ALLOW.search(e):
            findings.append((path, lineno, f"e-mail address ({e})", line))
    for ip in IPV4.findall(line):
        try:
            addr = ipaddress.ip_address(ip)
        except ValueError:
            continue
        if addr.is_global:
            findings.append((path, lineno, f"public IP address ({ip})", line))
    if HOME_PATH.search(line):
        findings.append((path, lineno, "personal home path", line))


def check_name(path, findings):
    for pat, what in FORBIDDEN_NAMES:
        if re.search(pat, path):
            findings.append((path, 0, f"forbidden file: {what}", ""))


def scan_staged():
    findings = []
    names = git("diff", "--cached", "--name-only", "--diff-filter=ACMR").split("\n")
    for path in filter(None, names):
        check_name(path, findings)
    diff = git("diff", "--cached", "-U0", "--no-color", "--diff-filter=ACMR")
    path, lineno = None, 0
    for raw in diff.split("\n"):
        if raw.startswith("+++ "):
            path = raw[6:] if raw.startswith("+++ b/") else None
        elif raw.startswith("@@"):
            lineno = int(re.search(r"\+(\d+)", raw).group(1))
        elif raw.startswith("+") and path and not TEXT_SKIP.search(path):
            check_line(path, lineno, raw[1:], findings)
            lineno += 1
    return findings


def scan_all():
    findings = []
    for path in filter(None, git("ls-files").split("\n")):
        check_name(path, findings)
        if TEXT_SKIP.search(path):
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                for i, line in enumerate(fh, 1):
                    check_line(path, i, line.rstrip("\n"), findings)
        except (UnicodeDecodeError, FileNotFoundError):
            continue
    return findings


def main():
    findings = scan_all() if "--all" in sys.argv else scan_staged()
    if not findings:
        print("secret-scan: clean")
        return 0
    print("secret-scan: possible secrets / private data — commit blocked:\n", file=sys.stderr)
    for path, lineno, what, line in findings:
        loc = f"{path}:{lineno}" if lineno else path
        shown = line.strip()
        if len(shown) > 100:
            shown = shown[:100] + "…"
        print(f"  {loc}  [{what}]", file=sys.stderr)
        if shown:
            print(f"      {shown}", file=sys.stderr)
    print(
        "\nFix: move the value to OpenBao and reference it via salt['sdb.get'](...) "
        "(.claude/docs/secrets.md).\nVerified false positive: append a 'secret-scan: allow' "
        "comment to that line.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
