// A JSON Schema validator covering exactly the subset that `protocol/*.schema.json` uses.
//
// Deliberately **not** a general Draft 2020-12 implementation: everything it does not
// support, it refuses loudly (see `unsupportedKeywords`), because a validator that silently
// ignores a keyword is a validator that silently stops checking something.
//
// This is one of the two places three implementations are most likely to drift apart, which
// is what `protocol/conformance/` exists to catch: the Rust validator, the Godot one and
// this one must produce the same error code at the same JSON Pointer for all 27 vectors.

import { SCHEMA_VIOLATION, UNKNOWN_FIELD, escapeSegment } from './codes.js';
import { Finding } from './report.js';

const KNOWN_KEYWORDS = new Set([
  '$schema', '$id', 'title', 'description', 'default', '$defs', '$ref',
  'type', 'const', 'required', 'properties', 'additionalProperties', 'propertyNames',
  'minProperties', 'maxProperties', 'minLength', 'maxLength', 'pattern',
  'minimum', 'maximum', 'minItems', 'maxItems', 'items', 'oneOf', 'not',
]);

const isPlainObject = (v) => typeof v === 'object' && v !== null && !Array.isArray(v);

/// Length in code points, not UTF-16 code units.
///
/// `"🌌".length` is 2 in JavaScript and 1 in both other implementations. No shipped schema
/// has a bound tight enough for that to bite today, but a validator that counts differently
/// from its siblings is a divergence waiting for the world that trips it.
const codePoints = (s) => [...s].length;

/// Returns every keyword used anywhere in `schema` that this subset does not implement.
///
/// The walk is schema-aware rather than a blind recursion: under `properties` and `$defs`
/// the keys are *names*, not keywords, and `const`/`default` hold arbitrary data that must
/// not be read as a schema at all.
export function unsupportedKeywords(schema, found = new Set()) {
  if (!isPlainObject(schema)) return [...found].sort();
  for (const [k, v] of Object.entries(schema)) {
    if (!KNOWN_KEYWORDS.has(k)) found.add(k);
    switch (k) {
      case 'properties':
      case '$defs':
        if (isPlainObject(v)) for (const sub of Object.values(v)) unsupportedKeywords(sub, found);
        break;
      case 'items':
      case 'additionalProperties':
      case 'propertyNames':
      case 'not':
        unsupportedKeywords(v, found);
        break;
      case 'oneOf':
        if (Array.isArray(v)) for (const branch of v) unsupportedKeywords(branch, found);
        break;
      default:
        // required / const / default / scalars: data, not schemas.
        break;
    }
  }
  return [...found].sort();
}

export function validate(schema, instance) {
  const out = [];
  check(schema, instance, '', schema, out);
  return out;
}

function resolve(ref, root) {
  // Only local pointers appear in these schemas, and only local pointers are accepted:
  // following an external $ref would mean fetching a schema at validation time.
  if (!ref.startsWith('#/')) throw new Error(`unsupported $ref: ${ref}`);
  let node = root;
  for (const raw of ref.slice(2).split('/')) {
    const seg = raw.replaceAll('~1', '/').replaceAll('~0', '~');
    if (!isPlainObject(node) || !(seg in node)) throw new Error(`unresolvable $ref: ${ref}`);
    node = node[seg];
  }
  return isPlainObject(node) ? node : {};
}

function violation(out, path, detail) {
  out.push(new Finding(SCHEMA_VIOLATION, path, detail));
}

function typeMatches(want, v) {
  switch (want) {
    case 'object': return isPlainObject(v);
    case 'array': return Array.isArray(v);
    case 'string': return typeof v === 'string';
    case 'boolean': return typeof v === 'boolean';
    case 'null': return v === null;
    case 'number': return typeof v === 'number' && Number.isFinite(v);
    // JSON Schema: a number with zero fractional part is an integer, however it was spelled.
    case 'integer': return Number.isInteger(v);
    default: return false;
  }
}

/// True when `instance` satisfies `schema` with no findings. Used for oneOf / not, where
/// only the verdict matters.
function satisfies(schema, instance, root) {
  const scratch = [];
  check(schema, instance, '', root, scratch);
  return scratch.length === 0;
}

function check(schema, instance, path, root, out) {
  if ('$ref' in schema) {
    check(resolve(schema.$ref, root), instance, path, root, out);
    // Every schema here is either a bare $ref or a plain schema, never both.
    return;
  }

  if ('type' in schema && !typeMatches(schema.type, instance)) {
    violation(out, path, `expected type ${schema.type}`);
    return;
  }

  if ('const' in schema && instance !== schema.const) {
    violation(out, path, `expected the constant "${schema.const}"`);
    return;
  }

  // oneOf reports a single failure at its own location and does not descend, so a creator is
  // told "this component is not valid" rather than handed four parallel explanations of why
  // it is not each of the four things it could have been.
  if ('oneOf' in schema) {
    const matched = schema.oneOf.filter((b) => satisfies(b, instance, root)).length;
    if (matched !== 1) {
      violation(
        out, path,
        `matched ${matched} of the ${schema.oneOf.length} allowed shapes; exactly one is required`,
      );
      return;
    }
  }

  if ('not' in schema && satisfies(schema.not, instance, root)) {
    violation(out, path, 'matched a shape that is explicitly disallowed');
    return;
  }

  if (typeof instance === 'string') checkString(schema, instance, path, out);
  else if (Array.isArray(instance)) checkArray(schema, instance, path, root, out);
  else if (isPlainObject(instance)) checkObject(schema, instance, path, root, out);
  else if (typeof instance === 'number') checkNumber(schema, instance, path, out);
}

function checkString(schema, s, path, out) {
  const n = codePoints(s);
  if ('minLength' in schema && n < schema.minLength) {
    violation(out, path, `shorter than ${schema.minLength} characters`);
  }
  if ('maxLength' in schema && n > schema.maxLength) {
    violation(out, path, `longer than ${schema.maxLength} characters`);
  }
  if ('pattern' in schema && !new RegExp(schema.pattern, 'u').test(s)) {
    violation(out, path, `does not match the pattern "${schema.pattern}"`);
  }
}

function checkNumber(schema, n, path, out) {
  if (typeof schema.minimum === 'number' && n < schema.minimum) {
    violation(out, path, `below the minimum ${schema.minimum}`);
  }
  if (typeof schema.maximum === 'number' && n > schema.maximum) {
    violation(out, path, `above the maximum ${schema.maximum}`);
  }
}

function checkArray(schema, arr, path, root, out) {
  if ('minItems' in schema && arr.length < schema.minItems) {
    violation(out, path, `fewer than ${schema.minItems} items`);
  }
  if ('maxItems' in schema && arr.length > schema.maxItems) {
    violation(out, path, `more than ${schema.maxItems} items`);
  }
  if ('items' in schema) {
    arr.forEach((item, i) => check(schema.items, item, `${path}/${i}`, root, out));
  }
}

function checkObject(schema, obj, path, root, out) {
  const keys = Object.keys(obj);
  if ('minProperties' in schema && keys.length < schema.minProperties) {
    violation(out, path, `fewer than ${schema.minProperties} properties`);
  }
  if ('maxProperties' in schema && keys.length > schema.maxProperties) {
    violation(out, path, `more than ${schema.maxProperties} properties`);
  }

  for (const name of schema.required ?? []) {
    if (!(name in obj)) violation(out, path, `missing the required property "${name}"`);
  }

  if ('propertyNames' in schema) {
    for (const name of keys) {
      if (!satisfies(schema.propertyNames, name, root)) {
        violation(out, path, `the property name "${name}" is not allowed here`);
      }
    }
  }

  const props = schema.properties ?? {};
  const extra = schema.additionalProperties;

  for (const name of keys) {
    const child = `${path}/${escapeSegment(name)}`;
    if (name in props) {
      check(props[name], obj[name], child, root, out);
    } else if (extra === false) {
      // SPEC §9 leans on this: a package trying to smuggle a behaviour hook fails validation
      // instead of being quietly stripped, and the creator is told which field did it.
      out.push(new Finding(
        UNKNOWN_FIELD,
        child,
        `"${name}" is not defined by the schema; unknown fields are rejected, never ignored (SPEC §9)`,
      ));
    } else if (isPlainObject(extra)) {
      check(extra, obj[name], child, root, out);
    }
  }
}
