// Finding worlds, and refusing to trust them.
//
// This is `docs/REGISTRY.md`'s client contract, executed. Hashes are checked **and** the
// documents are validated anyway. The hashes prove the bytes are the ones the registry
// meant to serve; they prove nothing about whether it should have served them. ADR-0001 §4
// puts the server first in line and the client second, and neither trusts the other -- a
// client that validates only what arrived over a channel it trusts has moved its security
// boundary onto somebody else's disk.

import { Context, validate, KIND_ITEMS, KIND_WORLD } from '../protocol/validator.js';
import * as Version from '../protocol/version.js';
import { localized } from './geometry.js';

async function sha256Hex(bytes) {
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Fetches bytes over HTTP. The only I/O this class does, injectable so the hash and
/// validation logic can be exercised without a server.
async function httpFetchBytes(url) {
  const res = await fetch(new URL(url, globalThis.location?.href ?? 'http://localhost/'));
  if (!res.ok) throw new Error(`${url}: HTTP ${res.status}`);
  return new Uint8Array(await res.arrayBuffer());
}

export class Registry {
  constructor({ fetchBytes = httpFetchBytes } = {}) {
    this.fetchBytes = fetchBytes;
    /** world id -> { world, itemsDoc, itemIds } */
    this.worlds = new Map();
    /** world id -> reason it was refused */
    this.rejected = new Map();
    this.base = '';
  }

  get ids() {
    return [...this.worlds.keys()].sort();
  }

  has(id) {
    return this.worlds.has(id);
  }

  world(id) {
    return this.worlds.get(id)?.world ?? null;
  }

  itemsDoc(id) {
    return this.worlds.get(id)?.itemsDoc ?? null;
  }

  displayName(id, locale = 'en') {
    const w = this.world(id);
    return w ? localized(w.display_name, locale, id) : id;
  }

  /// The spawn position for a world, falling back to `default` when the named one is absent.
  spawnPoint(id, spawnName) {
    const spawns = this.world(id)?.spawns;
    if (!spawns) return null;
    return (spawns[spawnName] ?? spawns.default)?.at ?? null;
  }

  /// Loads everything a registry offers. Returns the ids that were accepted.
  async loadFrom(baseUrl) {
    this.base = baseUrl.replace(/\/+$/, '');
    this.worlds.clear();
    this.rejected.clear();

    const index = await this.#fetchJson(`${this.base}/index.json`);

    // An index advertising a protocol this client does not implement is not a list it can
    // use, so it is refused rather than partially consumed.
    const declared = Version.parse(index.protocol_version ?? '');
    if (!declared || !Version.accepts(declared)) {
      throw new Error(
        `registry advertises protocol ${index.protocol_version}; this client implements ${Version.VERSION_STRING}`,
      );
    }

    for (const entry of index.worlds ?? []) {
      try {
        await this.#ingest(entry);
      } catch (e) {
        this.rejected.set(entry?.id ?? '<unnamed>', e.message);
      }
    }
    return this.ids;
  }

  async #ingest(entry) {
    const manifestBytes = await this.fetchBytes(`${this.base}/../${entry.manifest}`);
    const actual = await sha256Hex(manifestBytes);
    if (actual !== entry.sha256) {
      throw new Error(`manifest hash mismatch (index said ${entry.sha256}, got ${actual})`);
    }
    const manifest = JSON.parse(new TextDecoder().decode(manifestBytes));

    // Checking the manifest hash is enough to detect any change to the package, because
    // every file's hash is inside it -- but each file is checked too, since a serving
    // mistake is likelier than a deliberate one and both should be caught.
    const dir = `${this.base}/worlds/${manifest.id}`;
    const files = new Map();
    for (const f of manifest.files ?? []) {
      const bytes = await this.fetchBytes(`${dir}/${f.path}`);
      if ((await sha256Hex(bytes)) !== f.sha256) throw new Error(`${f.path} hash mismatch`);
      if (bytes.byteLength !== f.size) throw new Error(`${f.path} size mismatch`);
      files.set(f.path, JSON.parse(new TextDecoder().decode(bytes)));
    }

    const world = files.get('world.json');
    if (!world) throw new Error('manifest lists no world.json');
    const itemsDoc = files.get('items.json') ?? null;

    const itemIds = (itemsDoc?.items ?? [])
      .filter((i) => typeof i?.id === 'string')
      .map((i) => i.id);

    const ctx = new Context({ worldId: world.id ?? manifest.id, knownItems: itemIds });

    const report = validate(KIND_WORLD, world, ctx);
    if (!report.ok) throw new Error(report.findings.map(String).join('; '));

    if (itemsDoc) {
      const itemsReport = validate(KIND_ITEMS, itemsDoc, ctx);
      if (!itemsReport.ok) throw new Error(itemsReport.findings.map(String).join('; '));
    }

    this.worlds.set(world.id, { world, itemsDoc, itemIds });
  }

  async #fetchJson(url) {
    return JSON.parse(new TextDecoder().decode(await this.fetchBytes(url)));
  }
}
