// The version acceptance rule from `protocol/SPEC.md` §2.2.

import { UNSUPPORTED_PROTOCOL_VERSION } from './codes.js';
import { Finding } from './report.js';

export const MAJOR = 0;
export const MINOR = 1;
export const PATCH = 0;
export const VERSION_STRING = '0.1.0';

/// SPEC §2.1: three non-negative integers, no leading zeros, no pre-release or build
/// metadata. Deliberately stricter than general semver -- the protocol has no use for the
/// extra forms, and accepting them would create two spellings of one version.
export function parse(s) {
  if (typeof s !== 'string') return null;
  const parts = s.split('.');
  if (parts.length !== 3) return null;
  const out = [];
  for (const p of parts) {
    if (p.length === 0) return null;
    if (p.length > 1 && p.startsWith('0')) return null;
    if (!/^[0-9]+$/.test(p)) return null;
    out.push(Number(p));
  }
  return out;
}

/// SPEC §2.2. Pre-1.0 the minor version is treated as breaking: a 0.1 implementation must
/// not silently accept a 0.2 document it does not understand.
export function accepts(doc) {
  if (!Array.isArray(doc) || doc.length !== 3) return false;
  if (doc[0] !== MAJOR) return false;
  return MAJOR === 0 ? doc[1] === MINOR : doc[1] <= MINOR;
}

/// Returns null when fine, or a Finding when validation must stop: once the version is
/// unsupported, every other check runs against a document shape this implementation does
/// not claim to understand, and would report noise the creator cannot act on.
export function check(doc, field) {
  const path = `/${field}`;
  const raw = doc?.[field];
  // Missing or non-string: let the schema report it as a schema_violation instead.
  if (typeof raw !== 'string') return null;

  const v = parse(raw);
  if (v === null) {
    return new Finding(
      UNSUPPORTED_PROTOCOL_VERSION,
      path,
      `"${raw}" is not a MAJOR.MINOR.PATCH version`,
    );
  }
  if (accepts(v)) return null;
  return new Finding(
    UNSUPPORTED_PROTOCOL_VERSION,
    path,
    `document declares ${raw}; this implementation implements ${VERSION_STRING}`,
  );
}
