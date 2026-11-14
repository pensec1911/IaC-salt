#!/usr/bin/python3 -I
# Managed by Salt (formulas/patchmon-agent) — do not edit.
#
# Self-enrols this host through PatchMon's auto-enrollment API and writes the
# returned per-host credentials to credentials.yml (0600), then deletes the
# token file. Prints neither the token nor the API key.
#
# Usage: patchmon-agent-enroll <token.json> <credentials.yml> <config.yml>
#   token.json: {"server_url", "key", "secret", "friendly_name"}
#   config.yml: optional — its host_id (if the agent wrote one) is sent along,
#               so a host that never reported gets its key re-issued instead
#               of a duplicate.
import json
import os
import re
import socket
import sys
import urllib.error
import urllib.request

token_file, creds_file, config_file = sys.argv[1:4]

with open(token_file) as f:
    token = json.load(f)  # secret-scan: allow
with open('/etc/machine-id') as f:
    machine_id = f.read().strip()

body = {
    'friendly_name': token['friendly_name'],
    'machine_id': machine_id,
    'metadata': {'hostname': socket.gethostname()},
}
try:
    with open(config_file) as f:
        m = re.search(r'^host_id:[ \t]*["\']?([A-Za-z0-9-]{1,64})', f.read(), re.M)
    if m:
        body['host_id'] = m.group(1)
except FileNotFoundError:
    pass

req = urllib.request.Request(
    token['server_url'].rstrip('/') + '/api/v1/auto-enrollment/enroll',
    data=json.dumps(body).encode(),
    method='POST',
    headers={
        'Content-Type': 'application/json',
        'X-Auto-Enrollment-Key': token['key'],
        'X-Auto-Enrollment-Secret': token['secret'],  # secret-scan: allow
    },
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        data = json.load(resp)
except urllib.error.HTTPError as e:
    detail = e.read(2000).decode('utf-8', 'replace')
    try:
        parsed = json.loads(detail)
        detail = parsed.get('code') or parsed.get('error') or parsed.get('message') or detail
    except (ValueError, AttributeError):
        pass
    sys.exit(f'patchmon enroll failed: HTTP {e.code}: {detail}')
except urllib.error.URLError as e:
    sys.exit(f'patchmon enroll failed: server unreachable: {e.reason}')

host = data['host']
# JSON strings are valid YAML double-quoted scalars.
content = f"api_id: {json.dumps(host['api_id'])}\napi_key: {json.dumps(host['api_key'])}\n"  # secret-scan: allow
tmp = creds_file + '.tmp'
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, 'w') as f:
    f.write(content)
os.replace(tmp, creds_file)
os.remove(token_file)

kind = 'key re-issued' if data.get('reenrolled') else 'new host'
print(f"patchmon: enrolled as {host.get('friendly_name')} ({kind}), status {host.get('status')}")
