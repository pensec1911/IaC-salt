// Used by .forgejo/workflows/trivy.yml: scans every pinned image in
// formulas/*/map.jinja with Trivy and keeps one Forgejo issue up to date.
// Needs: trivy on PATH, FORGEJO_TOKEN, GITHUB_SERVER_URL, GITHUB_REPOSITORY.
import { execFileSync } from 'node:child_process';
import { readdirSync, readFileSync, existsSync } from 'node:fs';

const TITLE = 'Trivy: HIGH/CRITICAL CVEs in pinned images';
const SEVERITY = 'HIGH,CRITICAL';
const MAX_ROWS = 25; // per image, keeps the issue readable

// Same shape Renovate's regex manager expects (renovate.json): an 'image'
// line directly followed by its 'tag' line, plus prefixed pairs
// (dind_image/dind_tag, postgres_image/postgres_tag, …).
const PAIR = /'([a-z]+_)?image':\s*'([^']+)',\s*\n\s*'\1tag':\s*'([^']+)'/g;

function pinnedImages() {
  const refs = new Map(); // ref -> [formula, ...]
  for (const formula of readdirSync('formulas').sort()) {
    const path = `formulas/${formula}/map.jinja`;
    if (!existsSync(path)) continue;
    for (const m of readFileSync(path, 'utf8').matchAll(PAIR)) {
      const ref = `${m[2]}:${m[3]}`;
      refs.set(ref, [...(refs.get(ref) ?? []), formula]);
    }
  }
  return refs;
}

// The runner exports the Forgejo job token as GITHUB_TOKEN; Trivy would send
// it to ghcr.io as credentials and get DENIED. Anonymous pulls work.
const { GITHUB_TOKEN, ...trivyEnv } = process.env;

function trivy(args) {
  return execFileSync('trivy', args, {
    encoding: 'utf8', maxBuffer: 256 << 20, stdio: ['ignore', 'pipe', 'pipe'], env: trivyEnv,
  });
}

function scan(ref) {
  const out = trivy([
    'image', '--quiet', '--format', 'json', '--scanners', 'vuln',
    '--severity', SEVERITY, '--ignore-unfixed', '--skip-db-update',
    '--image-src', 'remote', '--platform', 'linux/amd64', ref,
  ]);
  const vulns = new Map(); // dedupe the same CVE+package across layers/targets
  for (const result of JSON.parse(out).Results ?? []) {
    for (const v of result.Vulnerabilities ?? []) {
      vulns.set(`${v.VulnerabilityID}|${v.PkgName}`, {
        id: v.VulnerabilityID, sev: v.Severity, pkg: v.PkgName,
        installed: v.InstalledVersion, fixed: v.FixedVersion,
      });
    }
  }
  const order = { CRITICAL: 0, HIGH: 1 };
  return [...vulns.values()].sort((a, b) => order[a.sev] - order[b.sev] || a.id.localeCompare(b.id));
}

async function api(path, init = {}) {
  const res = await fetch(`${process.env.GITHUB_SERVER_URL}/api/v1/repos/${process.env.GITHUB_REPOSITORY}${path}`, {
    ...init,
    headers: { Authorization: `token ${process.env.FORGEJO_TOKEN}`, 'Content-Type': 'application/json' },
  });
  if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path}: ${res.status} ${await res.text()}`);
  return res.status === 204 ? null : res.json();
}

const cell = (s) => String(s).replaceAll('|', '\\|');

// --- scan
trivy(['image', '--quiet', '--download-db-only']);
const db = JSON.parse(trivy(['version', '--format', 'json'])).VulnerabilityDB ?? {};
const images = pinnedImages();
const findings = []; // { ref, formulas, vulns }
const errors = [];
for (const [ref, formulas] of images) {
  console.log(`scanning ${ref}`);
  try {
    const vulns = scan(ref);
    if (vulns.length) findings.push({ ref, formulas, vulns });
    console.log(`  ${vulns.length} finding(s)`);
  } catch (e) {
    errors.push({ ref, msg: (e.stderr || e.message || '').trim().split('\n').slice(-3).join(' ') });
    console.log(`  error: ${errors.at(-1).msg}`);
  }
}

// --- report
const total = findings.reduce((n, f) => n + f.vulns.length, 0);
const run = `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_NUMBER}`;
let body = `Updated by [trivy.yml](${run}) — ${new Date().toISOString().slice(0, 16).replace('T', ' ')} UTC, ` +
  `${images.size} images, Trivy DB ${db.UpdatedAt?.slice(0, 10) ?? '?'}.\n\n` +
  `Only ${SEVERITY} with a fixed package version upstream (\`--ignore-unfixed\`). ` +
  `Fix = a newer image tag (Renovate PR) that contains it; if upstream hasn't rebuilt yet, wait.\n\n`;
if (!total) body += '**Clean** — no fixable HIGH/CRITICAL vulnerabilities.\n';
for (const f of findings.sort((a, b) => b.vulns.length - a.vulns.length)) {
  const crit = f.vulns.filter((v) => v.sev === 'CRITICAL').length;
  body += `### \`${f.ref}\` — ${f.vulns.length} (${crit} critical)\n\nformulas: ${f.formulas.join(', ')}\n\n` +
    '| CVE | Severity | Package | Installed | Fixed |\n|---|---|---|---|---|\n' +
    f.vulns.slice(0, MAX_ROWS).map((v) =>
      `| ${v.id} | ${v.sev} | ${cell(v.pkg)} | ${cell(v.installed)} | ${cell(v.fixed)} |`).join('\n') +
    (f.vulns.length > MAX_ROWS ? `\n\n… and ${f.vulns.length - MAX_ROWS} more (see the job log)` : '') + '\n\n';
}
if (errors.length) {
  body += '### Scan errors\n\n' + errors.map((e) => `- \`${e.ref}\`: ${e.msg}`).join('\n') + '\n';
}
console.log(`\n${body}`);

// --- one issue, updated in place
const issues = await api(`/issues?state=all&type=issues&q=${encodeURIComponent('Trivy')}&limit=50`);
const issue = issues.find((i) => i.title === TITLE);
const open = total > 0 || errors.length > 0;
if (issue) {
  await api(`/issues/${issue.number}`, { method: 'PATCH', body: JSON.stringify({ body, state: open ? 'open' : 'closed' }) });
  console.log(`issue #${issue.number} updated (${open ? 'open' : 'closed'})`);
} else if (open) {
  const created = await api('/issues', { method: 'POST', body: JSON.stringify({ title: TITLE, body }) });
  console.log(`issue #${created.number} created`);
}

if (errors.length) process.exit(1); // visible as a red run too
