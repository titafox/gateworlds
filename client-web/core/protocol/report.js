// A finding, and the report that collects them.

import { isAncestor, isSpecific } from './codes.js';

export class Finding {
  constructor(code, path, detail) {
    this.code = code;
    this.path = path;
    this.detail = detail;
  }

  /// Identity for comparison against a vector's expectations: code and location, not the
  /// human-readable detail. Implementations must agree on what went wrong and where; they
  /// are not required to phrase it identically.
  get key() {
    return `${this.code}\t${this.path}`;
  }

  toString() {
    return `${this.code} at ${this.path === '' ? '<root>' : this.path}: ${this.detail}`;
  }
}

export class Report {
  constructor(findings = []) {
    this.findings = findings;
  }

  get ok() {
    return this.findings.length === 0;
  }

  push(code, path, detail) {
    this.findings.push(new Finding(code, path, detail));
  }

  extend(others) {
    this.findings.push(...others);
  }

  /// SPEC §11: report every error found, not only the first. A creator fixing one error per
  /// round trip through review is a bad experience, and a bad experience means fewer worlds.
  ///
  /// Applies the specificity rule, then sorts and dedupes so output is stable regardless of
  /// the order the checks ran in.
  finish() {
    const specificPaths = this.findings.filter((f) => isSpecific(f.code)).map((f) => f.path);

    const kept = this.findings.filter((f) => {
      if (isSpecific(f.code)) return true;
      return !specificPaths.some((sp) => sp === f.path || isAncestor(f.path, sp));
    });

    kept.sort((a, b) => (a.path === b.path ? a.code.localeCompare(b.code) : a.path.localeCompare(b.path)));

    const seen = new Set();
    this.findings = kept.filter((f) => {
      if (seen.has(f.key)) return false;
      seen.add(f.key);
      return true;
    });
    return this;
  }
}
