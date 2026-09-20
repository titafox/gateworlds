// The third implementation, held to the same vectors as the other two.
//
// Run with `node --test client-web/tests/`. No dependencies: node:test is built in, and the
// client itself has none either.

import { strict as assert } from 'node:assert';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import * as Codes from '../core/protocol/codes.js';
import * as JsonSchema from '../core/protocol/json-schema.js';
import * as ResPath from '../core/protocol/respath.js';
import * as Version from '../core/protocol/version.js';
import { Report } from '../core/protocol/report.js';
import { runDir } from '../core/protocol/conformance.js';
import { KINDS, loadAll, schemaForSync } from '../core/protocol/schemas.js';

const repoRoot = fileURLToPath(new URL('../..', import.meta.url));

test('version: malformed strings are rejected', () => {
  for (const s of ['1', '1.2', '1.2.3.4', '01.2.3', '1.02.3', '1.2.3-rc1', '1.2.3+build', 'a.b.c', '']) {
    assert.equal(Version.parse(s), null, `should reject ${JSON.stringify(s)}`);
  }
  assert.deepEqual(Version.parse('0.1.0'), [0, 1, 0]);
});

test('version: pre-1.0 treats minor as breaking', () => {
  assert.ok(Version.accepts([0, 1, 0]));
  assert.ok(Version.accepts([0, 1, 7]), 'patch is ignored');
  assert.ok(!Version.accepts([0, 2, 0]), 'a 0.1 validator must reject 0.2');
  assert.ok(!Version.accepts([0, 0, 9]));
  assert.ok(!Version.accepts([1, 0, 0]));
  assert.deepEqual(Version.parse(Version.VERSION_STRING), [Version.MAJOR, Version.MINOR, Version.PATCH]);
});

test('resource paths: the five escape shapes the vectors cover', () => {
  for (const p of ['art/e.png', 'a', 'icons/herb.png', 'a/b/c/d_e-f.2.png', '_private/x.ogg']) {
    assert.equal(ResPath.check(p), '', `should accept ${p}`);
  }
  assert.equal(ResPath.check('../../../etc/passwd'), ResPath.BAD_FIRST);
  assert.equal(ResPath.check('/etc/passwd'), ResPath.BAD_FIRST);
  assert.match(ResPath.check('res://core/save_manager.gd'), /":"/);
  assert.match(ResPath.check('https://example.invalid/p.png'), /":"/);
  assert.match(ResPath.check('C:\\Windows\\System32'), /":"/);
  assert.equal(ResPath.check('art/../../secret.png'), ResPath.PARENT_SEGMENT);
  assert.equal(ResPath.check('art//e.png'), ResPath.EMPTY_SEGMENT);
  assert.equal(ResPath.check('art/'), ResPath.TRAILING);
  assert.equal(ResPath.check('art/e.'), ResPath.TRAILING);
  assert.equal(ResPath.check('./x.png'), ResPath.BAD_FIRST);
  assert.equal(ResPath.check(''), ResPath.EMPTY);
  assert.equal(ResPath.check('a'.repeat(256)), ResPath.TOO_LONG);
  assert.equal(ResPath.check('a'.repeat(255)), '');
});

test('findings: ancestry is segment-wise, not string prefix', () => {
  assert.ok(Codes.isAncestor('/entities/1', '/entities/1/components/0'));
  assert.ok(Codes.isAncestor('', '/anything'));
  assert.ok(!Codes.isAncestor('/entities/1', '/entities/10'));
  assert.ok(!Codes.isAncestor('/entities/1', '/entities/1'));
  assert.ok(!Codes.isAncestor('/a/b', '/a'));
  assert.equal(Codes.escapeSegment('a/b'), 'a~1b');
  assert.equal(Codes.escapeSegment('a~b'), 'a~0b');
});

test('findings: a specific code suppresses a generic one at or above it', () => {
  let r = new Report();
  r.push(Codes.SCHEMA_VIOLATION, '/entities/0/components/0/texture', 'pattern');
  r.push(Codes.INVALID_RESOURCE_PATH, '/entities/0/components/0/texture', 'escapes package');
  assert.equal(r.finish().findings.length, 1);
  assert.equal(r.findings[0].code, Codes.INVALID_RESOURCE_PATH);

  r = new Report();
  r.push(Codes.SCHEMA_VIOLATION, '/entities/1/components/0', 'oneOf');
  r.push(Codes.UNKNOWN_COMPONENT_TYPE, '/entities/1/components/0/type', 'summon_dragon');
  assert.equal(r.finish().findings.length, 1);

  r = new Report();
  r.push(Codes.SCHEMA_VIOLATION, '/spawns', 'missing default');
  r.push(Codes.DUPLICATE_ID, '/entities/1/id', 'twin');
  assert.equal(r.finish().findings.length, 2, 'an unrelated schema violation survives');
});

test('schema subset: the shipped schemas use no keyword this subset skips', async () => {
  await loadAll();
  for (const kind of KINDS) {
    assert.deepEqual(
      JsonSchema.unsupportedKeywords(schemaForSync(kind)), [],
      `${kind} schema uses only keywords this subset implements`,
    );
  }
});

test('schema subset: integers are judged by value, not by spelling', () => {
  const int = { type: 'integer' };
  assert.equal(JsonSchema.validate(int, 5).length, 0);
  assert.equal(JsonSchema.validate(int, 5.0).length, 0, 'a whole float is an integer');
  assert.ok(JsonSchema.validate(int, 5.5).length > 0);
  assert.ok(JsonSchema.validate(int, '5').length > 0);
  assert.ok(JsonSchema.validate({ type: 'number' }, true).length > 0, 'a bool is not a number');
});

test('schema subset: string length counts code points, not UTF-16 units', () => {
  // "🌌".length is 2 in JavaScript and 1 in both other implementations. Counting the way
  // JavaScript does would make this validator disagree with its siblings on a world whose
  // name happens to contain an emoji.
  assert.equal(JsonSchema.validate({ type: 'string', maxLength: 1 }, '🌌').length, 0);
  assert.ok(JsonSchema.validate({ type: 'string', maxLength: 1 }, 'ab').length > 0);
});

test('conformance: every vector passes', async () => {
  const outcomes = await runDir(join(repoRoot, 'protocol/conformance'));
  const failed = outcomes.filter((o) => o.failure !== '');
  assert.deepEqual(
    failed.map((o) => `${o.name}: ${o.failure}`), [],
    `${failed.length} of ${outcomes.length} vectors failed`,
  );
  assert.ok(outcomes.length >= 27, `expected at least 27 vectors, found ${outcomes.length}`);
});
