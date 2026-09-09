// Does the app read any JSON key the server never sends?
//
// WHY THIS EXISTS. The crew papers screen read credential['expiresAt'] while
// fleet-service has only ever sent expiresOn. The value came back null, a null
// date renders as nothing at all, and so the one screen a driver checks before
// a run showed no expiry and no day count — silently, for as long as the screen
// had existed. Nothing threw, nothing was logged, and neither `flutter analyze`
// nor the test suite could have caught it: both sides were valid on their own
// and only the agreement between them was wrong.
//
// Run from the student-app directory, with the eight service repos checked out
// beside it:
//
//     node tool/check_json_fields.js
//
// WHAT IT PROVES, AND WHAT IT DOES NOT. A key reported here appears in no
// backend source file at all, so nothing can be sending it — every instance of
// the bug above is in this list. It will NOT catch a key that is real but
// belongs to a different object: reading `name` where that model sends
// `fullName`, while some other model does have a `name`. Narrowing that needs
// captured response fixtures, which is the thing to build if this class of bug
// turns up again.
const fs = require('fs');
const path = require('path');

// Relative to this file, so it works from any checkout rather than only mine.
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

// Every backend source file, as one haystack.
let backend = '';
for (const root of SERVICES) {
  if (!fs.existsSync(root)) continue;
  for (const f of walk(root, '.ts')) backend += fs.readFileSync(f, 'utf8');
}

// The app's API layer is where JSON is decoded.
const apiFiles = walk(path.join(APP, 'api'), '.dart')
  .concat(walk(path.join(APP, 'screens'), '.dart'));

// j['foo'], json['foo'], data['foo'], person['foo'] … any map read by literal.
const READ = /\b([A-Za-z_][A-Za-z0-9_]*)\s*(?:\?)?\[\s*'([A-Za-z_][A-Za-z0-9_]*)'\s*\]/g;

const seen = new Map(); // key -> Set of "file:line"
for (const f of apiFiles) {
  const src = fs.readFileSync(f, 'utf8');
  const lines = src.split(/\r?\n/);
  lines.forEach((line, i) => {
    // Skip comments and obvious non-JSON maps.
    if (/^\s*(\/\/|\*|\/\*)/.test(line)) return;
    let m;
    READ.lastIndex = 0;
    while ((m = READ.exec(line))) {
      const recv = m[1];
      const key = m[2];
      // Local Dart maps, i18n tables and style maps are not server payloads.
      if (/^(_?strings?|_?en|_?ckb|_?ar|_?map|_?byKind|_?tints?|values|args|fields|headers)$/i.test(recv)) continue;
      if (!seen.has(key)) seen.set(key, new Set());
      seen.get(key).add(`${path.relative(APP, f).replace(/\\/g, '/')}:${i + 1}`);
    }
  });
}

const suspects = [];
for (const [key, where] of seen) {
  // Does any backend file mention this key at all?
  const re = new RegExp(`\\b${key}\\b`);
  if (!re.test(backend)) suspects.push({ key, where: [...where] });
}

console.log(`app JSON keys read: ${seen.size}`);
console.log(`never mentioned anywhere in the backend: ${suspects.length}\n`);
for (const s of suspects.sort((a, b) => a.key.localeCompare(b.key))) {
  console.log(`  ${s.key}`);
  for (const w of s.where.slice(0, 4)) console.log(`      ${w}`);
}
