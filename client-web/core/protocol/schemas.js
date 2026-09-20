// Loading the three schemas, in a browser and in Node, from one path expression.
//
// `client-web/protocol` is a symlink to the repository's `protocol/`, so this client
// compiles the schemas from the one normative source -- the same arrangement the Godot
// client uses and the same intent as the Rust crate's `include_str!`. Two copies of a
// schema are two schemas.

export const KINDS = ['world', 'items', 'save'];

const FILES = {
  world: 'world-v0.1.schema.json',
  items: 'items-v0.1.schema.json',
  save: 'save-v0.1.schema.json',
};

const isNode = typeof process !== 'undefined' && process.versions?.node != null;
const cache = new Map();

export async function schemaFor(kind) {
  if (!FILES[kind]) throw new Error(`unknown document kind: ${kind}`);
  if (cache.has(kind)) return cache.get(kind);

  const url = new URL(`../../protocol/${FILES[kind]}`, import.meta.url);
  const schema = isNode
    ? JSON.parse(await (await import('node:fs/promises')).readFile(url, 'utf8'))
    : await (await fetch(url)).json();

  cache.set(kind, schema);
  return schema;
}

/// Loads all three up front, so a caller can validate synchronously afterwards.
export async function loadAll() {
  await Promise.all(KINDS.map(schemaFor));
}

export function schemaForSync(kind) {
  const schema = cache.get(kind);
  if (!schema) throw new Error(`schema ${kind} not loaded; await loadAll() first`);
  return schema;
}
