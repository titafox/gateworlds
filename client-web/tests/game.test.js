// The browser client's game layer, tested without a browser.
//
// A registry is built here from the *real* world packages, hashed the way the publisher
// hashes them, so the hash checks and the validation run against real content rather than
// against a fixture that can quietly stop resembling one.

import { strict as assert } from 'node:assert';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

import { Game } from '../core/game.js';
import { Registry } from '../core/world/registry.js';
import { Inventory } from '../core/inventory.js';
import { ItemCatalog } from '../core/catalog.js';
import { SaveManager } from '../core/save.js';
import { buildRuntime } from '../core/world/loader.js';
import { centreOf, localized, rectFor, rectsOverlap } from '../core/world/geometry.js';
import { dimOn, panelFor, textOn, toRgb } from '../ui/hud.js';
import { loadAll } from '../core/protocol/schemas.js';

const repoRoot = fileURLToPath(new URL('../..', import.meta.url));
const HERB = 'xianxia_gate:spirit_herb';

async function sha256Hex(bytes) {
  const d = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

/// Builds an in-memory registry tree from the shipped worlds, laid out as
/// `gateworlds-validate publish` lays one out, and hands back a fetcher over it.
async function realRegistry({ corrupt = null } = {}) {
  const files = new Map();
  const entries = [];

  for (const id of ['pastoral_village', 'xianxia_gate']) {
    const manifestFiles = [];
    for (const name of ['world.json', 'items.json']) {
      const bytes = new Uint8Array(await readFile(join(repoRoot, 'worlds', id, name)));
      files.set(`/v0/worlds/${id}/${name}`, bytes);
      manifestFiles.push({ path: name, size: bytes.byteLength, sha256: await sha256Hex(bytes) });
    }
    const world = JSON.parse(new TextDecoder().decode(files.get(`/v0/worlds/${id}/world.json`)));
    const manifest = {
      registry_version: '0.1.0',
      protocol_version: '0.1.0',
      id,
      display_name: world.display_name,
      files: manifestFiles,
    };
    const mBytes = new TextEncoder().encode(`${JSON.stringify(manifest, null, 2)}\n`);
    files.set(`/v0/worlds/${id}/manifest.json`, mBytes);
    entries.push({
      id,
      display_name: world.display_name,
      manifest: `v0/worlds/${id}/manifest.json`,
      sha256: await sha256Hex(mBytes),
    });
  }

  if (corrupt === 'manifest-hash') entries[1].sha256 = '0'.repeat(64);
  if (corrupt === 'file-bytes') {
    const key = '/v0/worlds/xianxia_gate/world.json';
    const bytes = new Uint8Array(files.get(key));
    bytes[bytes.length - 2] = 32; // a byte the publisher never hashed
    files.set(key, bytes);
  }

  const index = {
    registry_version: '0.1.0',
    protocol_version: corrupt === 'protocol' ? '0.2.0' : '0.1.0',
    generated_at: '2026-01-01T00:00:00Z',
    worlds: entries,
  };
  files.set('/v0/index.json', new TextEncoder().encode(`${JSON.stringify(index, null, 2)}\n`));

  return async (url) => {
    // Normalise the `.../v0/../v0/worlds/...` shape the client builds from a manifest path.
    const path = new URL(url, 'http://registry.test/').pathname.replace('/v0/..', '');
    const bytes = files.get(path) ?? files.get(`/v0${path}`);
    if (!bytes) throw new Error(`${path}: HTTP 404`);
    return bytes;
  };
}

async function loadedRegistry(opts) {
  await loadAll();
  const registry = new Registry({ fetchBytes: await realRegistry(opts) });
  await registry.loadFrom('http://registry.test/v0');
  return registry;
}

class MemoryStorage {
  #map = new Map();
  getItem(k) { return this.#map.has(k) ? this.#map.get(k) : null; }
  setItem(k, v) { this.#map.set(k, String(v)); }
  removeItem(k) { this.#map.delete(k); }
}

test('geometry: `at` is a top-left origin, not a centre', () => {
  assert.deepEqual(rectFor({ x: 100, y: 50 }, { x: 0, y: 0 }, { w: 32, h: 16 }),
    { x: 100, y: 50, w: 32, h: 16 });
  assert.deepEqual(rectFor({ x: 100, y: 50 }, { x: -2, y: -2 }, { w: 20, h: 20 }),
    { x: 98, y: 48, w: 20, h: 20 }, 'offset shifts the rect, it does not recentre it');
  assert.deepEqual(centreOf({ x: 100, y: 50, w: 32, h: 16 }), { x: 116, y: 58 });
  assert.ok(rectsOverlap({ x: 0, y: 0, w: 10, h: 10 }, { x: 9, y: 9, w: 2, h: 2 }));
  assert.ok(!rectsOverlap({ x: 0, y: 0, w: 10, h: 10 }, { x: 10, y: 0, w: 2, h: 2 }));
});

test('localisation follows SPEC §4 and always returns something', () => {
  const names = { 'zh-CN': '青霄山门', en: 'Azure Sky Gate', ja: '青霄山門' };
  assert.equal(localized(names, 'zh-CN', 'x'), '青霄山门');
  assert.equal(localized(names, 'zh', 'x'), '青霄山门', 'primary subtag matches zh-CN');
  assert.equal(localized(names, 'de', 'x'), 'Azure Sky Gate', 'unknown locale falls back to en');
  assert.equal(localized({ ru: 'Врата', ja: '門' }, 'de', 'x'), '門',
    'with no en, the smallest key wins -- deterministic, never empty');
  assert.equal(localized(null, 'en', 'fallback'), 'fallback');
});

test('registry: the shipped worlds load, hashes and all', async () => {
  const registry = await loadedRegistry();
  assert.deepEqual(registry.ids, ['pastoral_village', 'xianxia_gate']);
  assert.equal(registry.rejected.size, 0);
  assert.equal(registry.displayName('xianxia_gate', 'zh-CN'), '青霄山门');
  assert.deepEqual(registry.spawnPoint('xianxia_gate', 'from_village'), [110, 228]);
  assert.deepEqual(registry.spawnPoint('xianxia_gate', 'nope'), [96, 96],
    'an unknown spawn falls back to default rather than stranding the player');
  assert.equal(registry.spawnPoint('nope', 'default'), null);
});

test('registry: a manifest whose hash does not match the index is refused', async () => {
  const registry = await loadedRegistry({ corrupt: 'manifest-hash' });
  assert.deepEqual(registry.ids, ['pastoral_village'], 'the sound world still loads');
  assert.match(registry.rejected.get('xianxia_gate'), /manifest hash mismatch/);
});

test('registry: a file whose bytes changed after publishing is refused', async () => {
  const registry = await loadedRegistry({ corrupt: 'file-bytes' });
  assert.ok(!registry.has('xianxia_gate'), 'a tampered file does not reach the game');
  assert.match(registry.rejected.get('xianxia_gate'), /hash mismatch/);
});

test('registry: an index advertising another protocol is refused whole', async () => {
  await loadAll();
  const registry = new Registry({ fetchBytes: await realRegistry({ corrupt: 'protocol' }) });
  await assert.rejects(() => registry.loadFrom('http://registry.test/v0'), /0\.2\.0/);
});

test('loader: a world becomes the lists the game needs, and nothing else', async () => {
  const registry = await loadedRegistry();
  const rt = buildRuntime(registry.world('xianxia_gate'));
  assert.equal(rt.worldId, 'xianxia_gate');
  assert.deepEqual(rt.bounds, { w: 640, h: 480 });
  assert.equal(rt.portals.length, 1);
  assert.equal(rt.pickups.length, 1);
  assert.equal(rt.portals[0].targetWorld, 'pastoral_village');
  assert.equal(rt.portals[0].targetSpawn, 'from_xianxia');
  assert.equal(rt.pickups[0].item, HERB);
  assert.equal(rt.pickups[0].entityId, 'herb_1');
  assert.ok(rt.solids.length >= 4, 'the walls are solid');

  const consumed = buildRuntime(registry.world('xianxia_gate'), ['herb_1']);
  assert.equal(consumed.pickups.length, 0, 'a taken pickup is not rebuilt');
  assert.ok(!consumed.visuals.some((v) => v.entityId === 'herb_1'),
    'and neither is its sprite -- the whole entity goes, as at runtime');
});

test('inventory: split stacks survive, and differing props are never merged', () => {
  const inv = new Inventory();
  inv.add(HERB, 1);
  inv.add(HERB, 2);
  assert.equal(inv.stacks.length, 1);
  assert.equal(inv.total(HERB), 3);

  inv.add('w:carrot', 5, 3);
  assert.equal(inv.total('w:carrot'), 5);
  assert.equal(inv.stacks.length, 3, 'a stack limit of 3 opens more stacks');

  const fresh = new Inventory();
  fresh.add('w:carrot', 1, 99, { freshness: 1 });
  fresh.add('w:carrot', 1, 99, { freshness: 0.3 });
  assert.equal(fresh.stacks.length, 2, 'stacks with different props stay apart');

  const loaded = new Inventory();
  loaded.fromSave([
    { item: 'w:carrot', count: 2, props: { freshness: 1 } },
    { item: 'w:carrot', count: 5, props: { freshness: 0.3 } },
  ]);
  assert.equal(loaded.stacks.length, 2, 'SPEC §10: loading must not merge split stacks');
  assert.equal(loaded.total('w:carrot'), 7);
  assert.deepEqual(loaded.itemIds(), ['w:carrot']);
});

test('catalog: the live definition wins, and nothing is ever dropped', async () => {
  const registry = await loadedRegistry();
  const cat = new ItemCatalog();
  cat.loadSnapshot({ [HERB]: { id: HERB, display_name: { en: 'Old Name' }, icon: { color: '#111111' } } });
  assert.equal(cat.displayName(HERB), 'Old Name', 'the snapshot resolves when nothing else does');

  cat.loadFromRegistry(registry);
  assert.equal(cat.displayName(HERB, 'zh-CN'), '灵草', 'the live definition takes precedence');

  assert.ok(!cat.isKnown('nobody:knows'), 'an unknown item is unknown');
  assert.equal(cat.displayName('nobody:knows'), 'nobody:knows',
    'and still renders as something rather than blank');
  assert.equal(Object.keys(cat.snapshotFor([HERB, 'nobody:knows'])).length, 2,
    'SPEC §8.2: the snapshot covers every held item, known or not');
});

test('save: refuses what it would not accept, in both directions', async () => {
  await loadAll();
  const saves = new SaveManager(new MemoryStorage());
  assert.ok(!saves.write({ player: { current_world: 'w' }, inventory: { stacks: [] }, item_defs: {} }),
    'a save missing a required field is refused at the write');
  assert.match(saves.lastError, /refusing to write/);

  const storage = new MemoryStorage();
  const s2 = new SaveManager(storage);
  storage.setItem('gateworlds.save.0', JSON.stringify({
    save_version: '0.2.0', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
    player: { current_world: 'w', at: [0, 0] }, inventory: { stacks: [] }, item_defs: {},
  }));
  assert.equal(s2.read(), null, 'a save from a newer protocol is refused, not guessed at');
  assert.match(s2.lastError, /0\.2\.0/);

  storage.setItem('gateworlds.save.0', '{ not json');
  assert.equal(s2.read(), null, 'a corrupt save is refused without throwing');
});

test('a save written by the Godot client loads here', async () => {
  // Not a fixture invented for this test: it is the conformance vector the other two
  // implementations validate, which is what makes it evidence for ADR-0001 §3's save
  // portability criterion rather than a self-consistent story.
  await loadAll();
  const vector = JSON.parse(await readFile(
    join(repoRoot, 'protocol/conformance/valid/save-cross-world-herb.json'), 'utf8'));

  const registry = await loadedRegistry();
  const game = new Game({ registry, storage: new MemoryStorage(), initialWorld: 'pastoral_village' });
  game.start();

  assert.ok(game.applyState(vector.document), 'the cross-world save applies');
  assert.equal(game.inventory.total(HERB), 1);
  assert.equal(game.inventory.total('pastoral_village:carrot'), 3);
  assert.equal(game.runtime.worldId, 'pastoral_village');
  assert.deepEqual(game.consumedIn('xianxia_gate'), ['herb_1']);
});

test('THE HERB COMES HOME: through the portal, back, saved, reopened', async () => {
  const registry = await loadedRegistry();
  const storage = new MemoryStorage();
  const game = new Game({ registry, storage, locale: 'zh-CN', initialWorld: 'pastoral_village' });

  assert.ok(game.start(), 'the game starts in the village');
  assert.deepEqual([game.player.x, game.player.y], [312, 232],
    'the player top-left sits on the spawn, not their centre');

  assert.ok(game.goto('xianxia_gate', 'from_village'));
  // Walk onto the herb rather than calling a handler: the trigger is the thing under test.
  game.player.x = 418;
  game.player.y = 298;
  game.update(0.016, { x: 0, y: 0 });
  assert.equal(game.inventory.total(HERB), 1, 'walking over the herb picks it up');
  assert.deepEqual(game.consumedIn('xianxia_gate'), ['herb_1'], 'and records it as taken');
  assert.equal(game.runtime.pickups.length, 0, 'it is gone from the world');

  assert.ok(game.goto('pastoral_village', 'from_xianxia'));
  assert.equal(game.inventory.total(HERB), 1,
    'THE HERB IS STILL THERE -- inventory belongs to the player, not to a world');
  assert.equal(game.catalog.displayName(HERB, 'zh-CN'), '灵草',
    'and the village can name an item it has never heard of');

  assert.ok(game.save(), game.saves.lastError);

  const reopened = new Game({ registry, storage, locale: 'zh-CN', initialWorld: 'pastoral_village' });
  reopened.start();
  assert.equal(reopened.inventory.total(HERB), 0, 'a new session starts empty');
  assert.ok(reopened.load(), reopened.saves.lastError);
  assert.equal(reopened.inventory.total(HERB), 1, 'THE HERB SURVIVED BEING CLOSED AND REOPENED');

  assert.ok(reopened.goto('xianxia_gate', 'from_village'));
  assert.equal(reopened.runtime.pickups.length, 0, 'and it has not grown back');
});

test('a withdrawn world costs the player nothing', async () => {
  const registry = await loadedRegistry();
  const game = new Game({ registry, storage: new MemoryStorage(), initialWorld: 'pastoral_village' });
  game.start();

  assert.ok(game.applyState({
    save_version: '0.1.0', created_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
    player: { current_world: 'a_world_that_was_withdrawn', at: [10, 10] },
    inventory: { stacks: [{ item: 'a_world_that_was_withdrawn:relic', count: 2 }] },
    item_defs: {
      'a_world_that_was_withdrawn:relic': {
        id: 'a_world_that_was_withdrawn:relic',
        display_name: { en: 'Relic' }, icon: { color: '#cccccc' },
      },
    },
    world_state: {},
  }), 'the save still loads');

  assert.equal(game.runtime.worldId, 'pastoral_village', 'the player is returned to the start');
  assert.equal(game.inventory.total('a_world_that_was_withdrawn:relic'), 2, 'AND KEEPS THEIR ITEMS');
  assert.equal(game.catalog.displayName('a_world_that_was_withdrawn:relic'), 'Relic',
    'the embedded snapshot still names an item whose world is gone');
});

test('a wall stops the player, and a portal does not fire on arrival', async () => {
  const registry = await loadedRegistry();
  const game = new Game({ registry, storage: new MemoryStorage(), initialWorld: 'pastoral_village' });
  game.start();

  for (let i = 0; i < 120; i += 1) game.update(1 / 60, { x: -1, y: 0 });
  assert.ok(game.player.x >= 16, `the wall stopped the player, x=${game.player.x}`);

  game.goto('xianxia_gate', 'from_village');
  assert.equal(game.portalsArmed, false, 'portals are disarmed on arrival');
  game.player.x = 40;
  game.player.y = 230; // inside the return portal at x 32..80, y 216..264
  game.update(1 / 60, { x: 0, y: 0 });
  assert.equal(game.runtime.worldId, 'xianxia_gate', 'standing in it on arrival does nothing');
});

test('hud colours are derived and checked, not assumed', () => {
  const lum = (c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
  // Every colour a world might declare, including the two extremes where the naive rule --
  // "darken it" -- has nowhere to go.
  for (const hex of [0x000000, 0x0a0a0a, 0x1b2430, 0x2e4a2e, 0x808080, 0xc9c9c9, 0xffffff, 0x7fe08a]) {
    const panel = panelFor(hex);
    assert.ok(Math.abs(lum(panel) - lum(toRgb(hex))) >= 0.055,
      `panel separates from ${hex.toString(16)}`);
    assert.ok(Math.abs(lum(textOn(panel)) - lum(panel)) > 0.35,
      `text is readable on the panel for ${hex.toString(16)}`);
    assert.ok(dimOn(panel) !== null);
  }
  assert.ok(lum(panelFor(0x000000)) > 0, 'a black world gets a lighter panel, not an invisible one');
  assert.ok(lum(panelFor(0xffffff)) < 1, 'a white world gets a darker one');
});

test('textures: a verified image reaches the renderer, an unverified one does not', async () => {
  await loadAll();

  // A three-pixel PNG, built here rather than read from the repository: a test that depends
  // on an art file breaks the day somebody redraws it.
  const png = Uint8Array.from(atob(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
  ), (c) => c.charCodeAt(0));

  const build = async ({ tamper = false } = {}) => {
    const files = new Map();
    const world = {
      protocol_version: '0.1.0', id: 'painted', display_name: { en: 'Painted' },
      bounds: { width: 64, height: 64 }, spawns: { default: { at: [0, 0] } },
      entities: [{
        id: 'wall', at: [8, 8],
        components: [{ type: 'sprite', size: [16, 16], texture: 'art/wall.png' }],
      }],
    };
    const worldBytes = new TextEncoder().encode(JSON.stringify(world));
    files.set('/v0/worlds/painted/world.json', worldBytes);
    files.set('/v0/worlds/painted/art/wall.png', png);

    const manifest = {
      registry_version: '0.1.0', protocol_version: '0.1.0', id: 'painted',
      display_name: world.display_name,
      files: [
        { path: 'world.json', size: worldBytes.byteLength, sha256: await sha256Hex(worldBytes) },
        {
          path: 'art/wall.png',
          size: png.byteLength,
          sha256: tamper ? '0'.repeat(64) : await sha256Hex(png),
        },
      ],
    };
    const mBytes = new TextEncoder().encode(JSON.stringify(manifest));
    files.set('/v0/worlds/painted/manifest.json', mBytes);

    const index = {
      registry_version: '0.1.0', protocol_version: '0.1.0',
      generated_at: '2026-01-01T00:00:00Z',
      worlds: [{
        id: 'painted', display_name: world.display_name,
        manifest: 'v0/worlds/painted/manifest.json', sha256: await sha256Hex(mBytes),
      }],
    };
    files.set('/v0/index.json', new TextEncoder().encode(JSON.stringify(index)));

    const registry = new Registry({
      fetchBytes: async (url) => {
        const path = new URL(url, 'http://registry.test/').pathname.replace('/v0/..', '');
        const bytes = files.get(path) ?? files.get(`/v0${path}`);
        if (!bytes) throw new Error(`${path}: HTTP 404`);
        return bytes;
      },
    });
    await registry.loadFrom('http://registry.test/v0');
    return registry;
  };

  const good = await build();
  assert.ok(good.has('painted'), `the painted world should load: ${[...good.rejected.values()]}`);
  const url = good.assets('painted').get('art/wall.png');
  assert.ok(url?.startsWith('data:image/png;base64,'), `expected a png data url, got ${url}`);

  const rt = buildRuntime(good.world('painted'), [], good.assets('painted'));
  assert.equal(rt.visuals[0].texture, url, 'the sprite carries the verified image');

  // An image is bytes a package asked a client to render. It gets the same treatment as
  // bytes a package asked it to obey.
  const bad = await build({ tamper: true });
  assert.ok(!bad.has('painted'), 'a world whose image fails its hash must not load');
  assert.match(bad.rejected.get('painted'), /hash mismatch/);
});
