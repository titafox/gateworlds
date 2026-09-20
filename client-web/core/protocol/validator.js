// Procedural checks and orchestration.
//
// Counterpart to `server/crates/gateworlds-protocol/src/validate.rs` and
// `client-godot/core/protocol/validator.gd`. The schema catches shape; these catch the
// rules a schema cannot express: version acceptance, the closed component whitelist,
// resource paths, uniqueness, reference resolution, item namespacing and bounds.

import * as Codes from './codes.js';
import * as JsonSchema from './json-schema.js';
import * as ResPath from './respath.js';
import * as Version from './version.js';
import { Report } from './report.js';
import { schemaForSync } from './schemas.js';

/// The closed component whitelist, SPEC §7. Adding to this is a protocol change.
export const COMPONENT_TYPES = ['sprite', 'solid', 'portal', 'pickup'];

export const KIND_WORLD = 'world';
export const KIND_ITEMS = 'items';
export const KIND_SAVE = 'save';

export function versionField(kind) {
  return kind === KIND_SAVE ? 'save_version' : 'protocol_version';
}

/// Facts a document cannot carry about itself. Stated explicitly by the caller -- a
/// conformance vector declares it in `$vector.context`, a package loader derives it from the
/// package it is reading. Never inferred from the expected outcome.
export class Context {
  constructor({ worldId = '', knownItems = [] } = {}) {
    this.worldId = worldId;
    this.knownItems = new Set(knownItems);
  }
}

const isPlainObject = (v) => typeof v === 'object' && v !== null && !Array.isArray(v);
const isNumber = (v) => typeof v === 'number' && Number.isFinite(v);

export function validate(kind, doc, ctx = new Context()) {
  const report = new Report();

  if (!isPlainObject(doc)) {
    report.push(Codes.SCHEMA_VIOLATION, '', 'the document is not a JSON object');
    return report.finish();
  }

  // SPEC §2.2: stop here on an unsupported version. Every later check would run against a
  // document shape this implementation does not claim to understand, and would report noise
  // the creator cannot act on.
  const versionProblem = Version.check(doc, versionField(kind));
  if (versionProblem) {
    report.findings.push(versionProblem);
    return report.finish();
  }

  report.extend(JsonSchema.validate(schemaForSync(kind), doc));

  if (kind === KIND_WORLD) checkWorld(doc, ctx, report);
  else if (kind === KIND_ITEMS) checkItems(doc, ctx, report);
  else if (kind === KIND_SAVE) checkSave(doc, report);

  return report.finish();
}

// ------------------------------------------------------------------------------- world

function checkWorld(doc, ctx, r) {
  const bounds = doc.bounds;
  const w = isPlainObject(bounds) ? bounds.width : undefined;
  const h = isPlainObject(bounds) ? bounds.height : undefined;

  if (isPlainObject(doc.spawns)) {
    for (const [name, spawn] of Object.entries(doc.spawns)) {
      if (isPlainObject(spawn)) checkInBounds(spawn.at, w, h, `/spawns/${name}/at`, r);
    }
  }

  if (!Array.isArray(doc.entities)) return;
  const seenIds = new Map();

  doc.entities.forEach((entity, i) => {
    if (!isPlainObject(entity)) return;

    if (typeof entity.id === 'string') {
      if (seenIds.has(entity.id)) {
        r.push(
          Codes.DUPLICATE_ID, `/entities/${i}/id`,
          `entity id "${entity.id}" is already used at /entities/${seenIds.get(entity.id)}`,
        );
      } else {
        seenIds.set(entity.id, i);
      }
    }

    checkInBounds(entity.at, w, h, `/entities/${i}/at`, r);
    if (!Array.isArray(entity.components)) return;

    const seenTypes = new Map();
    entity.components.forEach((comp, j) => {
      if (!isPlainObject(comp)) return;
      const base = `/entities/${i}/components/${j}`;
      const ty = comp.type;
      if (typeof ty !== 'string') return;

      if (!COMPONENT_TYPES.includes(ty)) {
        r.push(
          Codes.UNKNOWN_COMPONENT_TYPE, `${base}/type`,
          `"${ty}" is not in the component whitelist (${COMPONENT_TYPES.join(', ')}); ` +
            'the set is closed and adding to it is a protocol change (SPEC §7)',
        );
        return;
      }

      if (seenTypes.has(ty)) {
        r.push(
          Codes.DUPLICATE_ID, `${base}/type`,
          `this entity already carries a "${ty}" component at ` +
            `/entities/${i}/components/${seenTypes.get(ty)}; draw and trigger order would be undefined`,
        );
      } else {
        seenTypes.set(ty, j);
      }

      if (ty === 'sprite') checkResource(comp.texture, `${base}/texture`, r);
      if (ty === 'pickup' && typeof comp.item === 'string' && !ctx.knownItems.has(comp.item)) {
        r.push(
          Codes.UNRESOLVED_REFERENCE, `${base}/item`,
          `"${comp.item}" is not defined in this package; in 0.1.0 a pickup must reference ` +
            'an item of its own package (SPEC §3.2)',
        );
      }
    });
  });
}

// ------------------------------------------------------------------------------- items

function checkItems(doc, ctx, r) {
  if (!Array.isArray(doc.items)) return;
  const seen = new Map();

  doc.items.forEach((item, i) => {
    if (!isPlainObject(item)) return;
    const path = `/items/${i}/id`;
    if (typeof item.id === 'string') {
      if (seen.has(item.id)) {
        r.push(Codes.DUPLICATE_ID, path,
          `item id "${item.id}" is already defined at /items/${seen.get(item.id)}`);
      } else {
        seen.set(item.id, i);
      }

      // SPEC §3.2: a world may only define items in its own namespace, or one world could
      // shadow another's items.
      const colon = item.id.indexOf(':');
      if (ctx.worldId !== '' && colon > 0) {
        const ns = item.id.slice(0, colon);
        if (ns !== ctx.worldId) {
          r.push(
            Codes.INVALID_ITEM_NAMESPACE, path,
            `namespace "${ns}" does not match the defining world "${ctx.worldId}"; ` +
              'a world may only define items in its own namespace',
          );
        }
      }
    }
    if (isPlainObject(item.icon)) {
      checkResource(item.icon.texture, `/items/${i}/icon/texture`, r);
    }
  });
}

// -------------------------------------------------------------------------------- save

function checkSave(doc, r) {
  const defs = isPlainObject(doc.item_defs) ? doc.item_defs : {};
  const stacks = isPlainObject(doc.inventory) ? doc.inventory.stacks : undefined;
  if (!Array.isArray(stacks)) return;

  stacks.forEach((stack, i) => {
    if (!isPlainObject(stack)) return;
    if (typeof stack.item === 'string' && !(stack.item in defs)) {
      r.push(
        Codes.UNRESOLVED_REFERENCE, `/inventory/stacks/${i}/item`,
        `no definition for "${stack.item}" in item_defs; a save must embed the definition ` +
          'of every item it holds, so that it survives its defining world being ' +
          'unpublished (SPEC §8.3)',
      );
    }
  });
}

// ------------------------------------------------------------------------------ shared

function checkInBounds(at, w, h, path, r) {
  if (!Array.isArray(at) || at.length < 2) return;
  if (!isNumber(w) || !isNumber(h)) return;
  const [x, y] = at;
  if (!isNumber(x) || !isNumber(y)) return;
  if (x < 0 || y < 0 || x > w || y > h) {
    r.push(Codes.VALUE_OUT_OF_RANGE, path, `[${x}, ${y}] lies outside the world bounds ${w}x${h}`);
  }
}

function checkResource(value, path, r) {
  if (typeof value !== 'string') return;
  const why = ResPath.check(value);
  if (why !== '') r.push(Codes.INVALID_RESOURCE_PATH, path, why);
}
