// Wiring: find a registry, load the worlds, run the loop.

import { Game } from './core/game.js';
import { Registry } from './core/world/registry.js';
import { loadAll } from './core/protocol/schemas.js';
import { Controls } from './input/controls.js';
import { Hud } from './ui/hud.js';
import { SceneView } from './render/scene.js';

/// Where to look for worlds, in order.
///
/// Deployed beside a registry, `./v0/` is that registry and nothing has to be configured.
/// Opened from a dev server, it falls back to the public one, which sets
/// `Access-Control-Allow-Origin: *` precisely so that a client somebody is building on their
/// own machine can reach it.
const PUBLIC_REGISTRY = 'https://gw.koko.kg/v0';

async function findRegistry() {
  const asked = new URLSearchParams(location.search).get('registry');
  const candidates = asked ? [asked] : [new URL('./v0', location.href).href, PUBLIC_REGISTRY];

  const problems = [];
  for (const base of candidates) {
    try {
      const registry = new Registry();
      await registry.loadFrom(base);
      if (registry.ids.length > 0) return { registry, base };
      problems.push(`${base}: no worlds offered`);
    } catch (e) {
      problems.push(`${base}: ${e.message}`);
    }
  }
  throw new Error(problems.join('\n'));
}

/// localStorage throws in a private window and in some embedded browsers. A game that
/// refuses to start because it cannot save is worse than one that runs and says so.
function safeStorage() {
  try {
    const probe = '__gw__';
    localStorage.setItem(probe, '1');
    localStorage.removeItem(probe);
    return localStorage;
  } catch {
    const map = new Map();
    return {
      getItem: (k) => (map.has(k) ? map.get(k) : null),
      setItem: (k, v) => map.set(k, String(v)),
      removeItem: (k) => map.delete(k),
      ephemeral: true,
    };
  }
}

function playerLocale() {
  const tag = navigator.language ?? 'en';
  return tag.toLowerCase().startsWith('zh') ? 'zh-CN' : tag.split('-')[0];
}

async function boot() {
  const loading = document.getElementById('loading');
  const loadingText = document.getElementById('loading-text');

  await loadAll();

  let registry;
  let base;
  try {
    ({ registry, base } = await findRegistry());
  } catch (e) {
    loadingText.style.whiteSpace = 'pre-wrap';
    loadingText.textContent = `No registry could be read.\n${e.message}`;
    return;
  }

  for (const [id, why] of registry.rejected) {
    // A refused world is a fact somebody should be able to discover, not a silence.
    console.warn(`[gateworlds] ${id} was refused and will not be offered: ${why}`);
  }

  const storage = safeStorage();
  const hud = new Hud(document.getElementById('hud'));
  const view = new SceneView(document.getElementById('view'));
  const game = new Game({ registry, storage, locale: playerLocale() });

  const refreshRows = () =>
    hud.setRows(
      game.inventory.stacks.map((s) => ({
        icon: game.catalog.iconColor(s.item),
        name: game.catalog.displayName(s.item, game.locale),
        origin: registry.displayName(s.item.split(':')[0], game.locale),
        count: s.count,
      })),
    );

  game.onWorldChange = (worldId, runtime) => {
    view.setWorld(runtime);
    hud.setWorld(registry.displayName(worldId, game.locale), runtime.background.hex);
    refreshRows();
  };
  game.onNotice = (text) => hud.notice(text);
  game.inventory.onChange = refreshRows;

  if (!game.start()) {
    loadingText.textContent = `The registry at ${base} has no world called ${game.initialWorld}.`;
    return;
  }
  loading.remove();
  if (storage.ephemeral) hud.notice('Saving is off: this browser blocks storage.');

  const stickEl = document.getElementById('stick');
  const knobEl = stickEl.querySelector('b');
  const controls = new Controls(document.getElementById('view'), {
    onKey: (code) => {
      if (code === 'KeyI') hud.toggleInventory();
      else if (code === 'F5') game.save();
      else if (code === 'F9') game.load();
    },
  });

  document.getElementById('btn-bag').onclick = () => hud.toggleInventory();
  document.getElementById('btn-save').onclick = () => game.save();
  document.getElementById('btn-load').onclick = () => game.load();
  addEventListener('resize', () => view.resize());

  let last = performance.now();
  const frame = (now) => {
    // Clamped: a backgrounded tab returns with a huge delta and would teleport the player
    // through a wall on the first step back.
    const dt = Math.min((now - last) / 1000, 0.05);
    last = now;

    game.update(dt, controls.direction());
    view.render(game.player, now / 1000);

    const stick = controls.stick;
    if (stick) {
      stickEl.style.display = 'block';
      stickEl.style.left = `${stick.ox}px`;
      stickEl.style.top = `${stick.oy}px`;
      const dx = stick.x - stick.ox;
      const dy = stick.y - stick.oy;
      const len = Math.hypot(dx, dy) || 1;
      const k = Math.min(len, 48) / len;
      knobEl.style.left = `${48 + dx * k}px`;
      knobEl.style.top = `${48 + dy * k}px`;
    } else {
      stickEl.style.display = 'none';
    }
    requestAnimationFrame(frame);
  };
  requestAnimationFrame(frame);
}

boot().catch((e) => {
  document.getElementById('loading-text').textContent = e.message;
  console.error(e);
});
