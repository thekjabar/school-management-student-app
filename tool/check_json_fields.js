const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const APP = path.join(ROOT, 'student-app', 'lib');
const SERVICES = [
  'identity-service', 'transport-service', 'students-service', 'tracking-service',
  'messages-service', 'money-service', 'fleet-service', 'school-work-service',
].map((s) => path.join(ROOT, s, 'src'));

function walk(dir, ext, out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, ext, out);
    else if (e.name.endsWith(ext)) out.push(p);
  }
  return out;
}

let backend = '';
for (const root of SERVICES) {
  if (!fs.existsSync(root)) continue;
  for (const f of walk(root, '.ts')) backend += fs.readFileSync(f, 'utf8');
}

const apiFiles = walk(path.join(APP, 'api'), '.dart')
  .concat(walk(path.join(APP, 'screens'), '.dart'));

const READ = /\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:\?)?\[\s*'([A-Za-z_][A-Za-z0-9_]*)'\s*\]/g;

const seen = new Map();
for (const f of apiFiles) {
  const src = fs.readFileSync(f, 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    if (/^\s*(\/\/|\*|\/\*)/.test(line)) return;
    let m;
    READ.lastIndex = 0;
    while ((m = READ.exec(line))) {
      const recv = m[1];
      const key = m[2];
      if (/^(_?strings?|_?en|_?ckb|_?ar|_?map|_?byKind|_?tints?|values|args|fields|headers)$/i.test(recv)) continue;
      if (!seen.has(key)) seen.set(key, new Set());
      seen.get(key).add(`${path.relative(APP, f).replace(/\\/g, '/')}:${i + 1}`);
    }
  });
}

const suspects = [];
for (const [key, where] of seen) {
  const re = new RegExp(`\\b${key}\\b`);
  if (!re.test(backend)) suspects.push({ key, where: [...where] });
}

console.log(`app JSON keys read: ${seen.size}`);
console.log(`never mentioned anywhere in the backend: ${suspects.length}\n`);
for (const s of suspects.sort((a, b) => a.key.localeCompare(b.key))) {
  console.log(`  ${s.key}`);
  for (const w of s.where.slice(0, 4)) console.log(`      ${w}`);
}
