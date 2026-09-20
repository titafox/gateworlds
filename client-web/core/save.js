// Reading and writing the save.
//
// A save is external content. It can be hand-edited in devtools, copied between browsers,
// or written by a different build -- so it is validated on the way in exactly like a world
// package is. The client does not get to trust a value merely because it wrote one there
// once.
//
// The format is the one in SPEC §10, the same shape as the Godot client's file. A save
// written there loads here, and the reverse. That is ADR-0001 §3's save-portability exit
// criterion, and it is only true because neither client invented its own shape.

import { Context, validate, KIND_SAVE } from './protocol/validator.js';
import * as Version from './protocol/version.js';

export const DEFAULT_KEY = 'gateworlds.save.0';

/// The seam for save migrations. Empty at 0.1.0 because there is nothing to migrate from;
/// it exists so the obligation in SPEC §2.3 is visible rather than remembered.
const STEPS = new Map();

export function migrate(doc) {
  let current = String(doc?.save_version ?? '');
  let out = doc;
  const seen = new Set();

  while (current !== Version.VERSION_STRING) {
    if (!STEPS.has(current)) {
      return {
        ok: false,
        doc: out,
        error:
          `save is version ${current || '<missing>'} and no migration to ` +
          `${Version.VERSION_STRING} exists; refusing to guess at a shape this build does not understand`,
      };
    }
    // A cycle would spin forever on a corrupt or hand-edited value.
    if (seen.has(current)) return { ok: false, doc: out, error: `migration cycle at ${current}` };
    seen.add(current);
    out = STEPS.get(current)(out);
    current = String(out?.save_version ?? '');
  }
  return { ok: true, doc: out, error: '' };
}

export function nowUtc() {
  return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
}

export class SaveManager {
  constructor(storage, key = DEFAULT_KEY) {
    this.storage = storage;
    this.key = key;
    this.lastError = '';
  }

  exists() {
    return this.storage.getItem(this.key) !== null;
  }

  write(state) {
    const doc = structuredClone(state);
    doc.save_version = Version.VERSION_STRING;
    doc.created_at ??= nowUtc();
    doc.updated_at = nowUtc();

    // Validate before writing, not only after reading. A build that can produce a save it
    // would itself refuse has a bug, and the time to find out is now.
    const report = validate(KIND_SAVE, doc, new Context());
    if (!report.ok) {
      this.lastError = `refusing to write an invalid save: ${report.findings.map(String).join('; ')}`;
      return false;
    }

    try {
      this.storage.setItem(this.key, JSON.stringify(doc, null, 2));
    } catch (e) {
      this.lastError = `cannot write the save: ${e.message}`;
      return false;
    }
    this.lastError = '';
    return true;
  }

  read() {
    this.lastError = '';
    const raw = this.storage.getItem(this.key);
    if (raw === null) {
      this.lastError = 'no save yet';
      return null;
    }

    let parsed;
    try {
      parsed = JSON.parse(raw);
    } catch (e) {
      this.lastError = `the save is not valid JSON: ${e.message}`;
      return null;
    }

    const migrated = migrate(parsed);
    if (!migrated.ok) {
      this.lastError = migrated.error;
      return null;
    }

    const report = validate(KIND_SAVE, migrated.doc, new Context());
    if (!report.ok) {
      this.lastError = `save did not validate: ${report.findings.map(String).join('; ')}`;
      return null;
    }
    return migrated.doc;
  }
}
