// The conformance vector runner, per `protocol/conformance/README.md`.
//
// Counterpart to the Rust and GDScript runners. All three run the same directory. Three
// independent implementations agreeing on it is the evidence ADR-0001 rests on; one
// implementation is just a habit.

import { Context, validate } from './validator.js';
import { KINDS, loadAll } from './schemas.js';

/// Evaluates one already-parsed vector. Returns { name, failure, report }.
export function evaluate(name, vector) {
  const meta = vector?.$vector;
  if (!meta) return { name, failure: 'missing $vector', report: null };
  if (!('document' in vector)) return { name, failure: 'missing document', report: null };

  const doc = vector.document;
  const kind = meta.kind;
  if (!KINDS.includes(kind)) return { name, failure: `unknown kind ${kind}`, report: null };

  if (meta.expect !== 'valid' && meta.expect !== 'invalid') {
    return { name, failure: `bad $vector.expect: ${meta.expect}`, report: null };
  }
  const expectValid = meta.expect === 'valid';
  const exhaustive = meta.exhaustive === true;

  // The context is stated by the vector, never inferred from `expect`. A runner that decided
  // how to validate by looking at the expected outcome would argue in a circle and pass its
  // own vectors whatever the validator did.
  const ctx = new Context({
    worldId: meta.context?.world_id ?? (typeof doc?.id === 'string' ? doc.id : ''),
    knownItems: Array.isArray(meta.context?.items) ? meta.context.items : [],
  });

  const report = validate(kind, doc, ctx);
  const got = new Set(report.findings.map((f) => f.key));

  if (expectValid) {
    return {
      name,
      report,
      failure: report.ok
        ? ''
        : `expected no findings, got: ${report.findings.map(String).join('; ')}`,
    };
  }

  const want = new Set((meta.errors ?? []).map((e) => `${e.code ?? '?'}\t${e.path ?? ''}`));
  const pretty = (k) => k.replace('\t', ' at ');

  const missing = [...want].filter((k) => !got.has(k)).map(pretty).sort();
  const extra = [...got].filter((k) => !want.has(k)).map(pretty).sort();

  const why = [];
  if (missing.length) why.push(`expected but not reported: ${missing.join('; ')}`);
  if (exhaustive && extra.length) {
    why.push(`reported but not expected (vector is exhaustive): ${extra.join('; ')}`);
  }
  return { name, report, failure: why.join(' | ') };
}

/// Runs every `*.json` under `<dir>/valid` and `<dir>/invalid`, in a stable order.
/// Node only: a browser cannot list a directory, and does not need to.
export async function runDir(dir) {
  const { readdir, readFile } = await import('node:fs/promises');
  const { join } = await import('node:path');
  await loadAll();

  const files = [];
  for (const sub of ['valid', 'invalid']) {
    const names = (await readdir(join(dir, sub))).filter((n) => n.endsWith('.json')).sort();
    for (const n of names) files.push([n, join(dir, sub, n)]);
  }
  if (files.length === 0) throw new Error(`no vectors found under ${dir}`);

  const out = [];
  for (const [name, path] of files) {
    let vector;
    try {
      vector = JSON.parse(await readFile(path, 'utf8'));
    } catch (e) {
      out.push({ name, failure: `vector is not valid JSON: ${e.message}`, report: null });
      continue;
    }
    out.push(evaluate(name, vector));
  }
  return out;
}
