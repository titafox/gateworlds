// The game.
//
// Knows about worlds, a player and portals. It does not know about villages, sects, herbs or
// farming -- search this file for any of them and there is none. The genre lives in the
// world data, which is how a contributor adds one without touching client code.
//
// Kept free of three.js so it can be tested without a browser, for the same reason the Godot
// client keeps its transitions callable without physics: a claim you can only check by
// looking at it is a claim nobody checks.

import { buildRuntime } from './world/loader.js';
import { coord, rectsOverlap } from './world/geometry.js';
import { ItemCatalog } from './catalog.js';
import { Inventory } from './inventory.js';
import { SaveManager, nowUtc } from './save.js';

export const PLAYER_SIZE = 16;
export const PLAYER_SPEED = 130;

export class Game {
  constructor({ registry, storage, locale = 'en', initialWorld = 'pastoral_village' }) {
    this.registry = registry;
    this.catalog = new ItemCatalog();
    this.inventory = new Inventory();
    this.saves = new SaveManager(storage);
    this.locale = locale;
    this.initialWorld = initialWorld;

    /// Top-left of the player, in protocol units -- the same anchoring as everything else.
    this.player = { x: 0, y: 0 };
    this.runtime = null;
    /// world id -> { consumed_pickups: [entityId] }. SPEC §10.
    this.worldState = {};
    this.createdAt = nowUtc();

    /// A portal the player is standing in must not fire until they have stepped out of it.
    /// Without this, arriving on a spawn that overlaps a portal bounces them back forever.
    /// World data can avoid that by placing spawns carefully, and the shipped worlds do --
    /// but a client that only works because the content is careful breaks on the first world
    /// a contributor sends.
    this.portalsArmed = false;

    this.onWorldChange = () => {};
    this.onNotice = () => {};
  }

  start() {
    this.catalog.loadFromRegistry(this.registry);
    return this.goto(this.initialWorld, 'default');
  }

  get playerRect() {
    return { x: this.player.x, y: this.player.y, w: PLAYER_SIZE, h: PLAYER_SIZE };
  }

  consumedIn(worldId) {
    const list = this.worldState[worldId]?.consumed_pickups;
    return Array.isArray(list) ? list : [];
  }

  #recordConsumed(worldId, entityId) {
    this.worldState[worldId] ??= { consumed_pickups: [] };
    const list = this.worldState[worldId].consumed_pickups;
    if (!list.includes(entityId)) list.push(entityId);
  }

  /// Swaps the current world for another and puts the player on the named spawn.
  ///
  /// Returns false rather than half-loading when the destination is unknown: a portal may
  /// name a world this client does not have (SPEC §7.3 allows exactly that), and the right
  /// answer is to stay where you are.
  goto(worldId, spawnName) {
    if (!this.registry.has(worldId)) return false;
    const at = this.registry.spawnPoint(worldId, spawnName);
    if (at === null) return false;

    this.runtime = buildRuntime(this.registry.world(worldId), this.consumedIn(worldId));
    const p = coord(at);
    this.player.x = p.x;
    this.player.y = p.y;
    this.portalsArmed = false;
    this.onWorldChange(worldId, this.runtime);
    return true;
  }

  /// One step. `dir` is a vector of at most unit length from whatever input the platform has.
  update(dt, dir) {
    if (!this.runtime) return;
    const step = PLAYER_SPEED * dt;
    this.#move(dir.x * step, 0);
    this.#move(0, dir.y * step);
    this.#triggers();
  }

  /// Axis-separated collision: move on one axis, push back out of anything solid, repeat.
  /// Simple, and it slides along walls the way a player expects without a physics engine.
  #move(dx, dy) {
    if (dx === 0 && dy === 0) return;
    this.player.x += dx;
    this.player.y += dy;

    const me = this.playerRect;
    for (const solid of this.runtime.solids) {
      if (!rectsOverlap(me, solid.rect)) continue;
      if (dx > 0) this.player.x = solid.rect.x - PLAYER_SIZE;
      else if (dx < 0) this.player.x = solid.rect.x + solid.rect.w;
      if (dy > 0) this.player.y = solid.rect.y - PLAYER_SIZE;
      else if (dy < 0) this.player.y = solid.rect.y + solid.rect.h;
      me.x = this.player.x;
      me.y = this.player.y;
    }
  }

  #triggers() {
    const me = this.playerRect;

    if (!this.portalsArmed) {
      if (!this.runtime.portals.some((p) => rectsOverlap(me, p.rect))) this.portalsArmed = true;
    } else {
      for (const portal of this.runtime.portals) {
        if (rectsOverlap(me, portal.rect)) {
          this.portalsArmed = false;
          this.goto(portal.targetWorld, portal.targetSpawn);
          return;
        }
      }
    }

    for (let i = this.runtime.pickups.length - 1; i >= 0; i -= 1) {
      const pickup = this.runtime.pickups[i];
      if (!rectsOverlap(me, pickup.rect)) continue;

      this.inventory.add(pickup.item, pickup.count, this.catalog.stackLimit(pickup.item));
      this.onNotice(`Picked up ${this.catalog.displayName(pickup.item, this.locale)} ×${pickup.count}`);

      if (pickup.once) {
        this.#recordConsumed(this.runtime.worldId, pickup.entityId);
        this.runtime.pickups.splice(i, 1);
        this.runtime.visuals = this.runtime.visuals.filter((v) => v.entityId !== pickup.entityId);
        this.onWorldChange(this.runtime.worldId, this.runtime);
      }
    }
  }

  // ---------------------------------------------------------------------------- saving

  /// Everything that has to survive being closed. SPEC §10.
  captureState() {
    return {
      created_at: this.createdAt,
      player: {
        current_world: this.runtime.worldId,
        at: [Math.round(this.player.x), Math.round(this.player.y)],
      },
      inventory: { stacks: this.inventory.toSave() },
      // SPEC §8.3: the definitions travel with the save, so it stays readable even if the
      // world that defined them is gone.
      item_defs: this.catalog.snapshotFor(this.inventory.itemIds()),
      world_state: structuredClone(this.worldState),
    };
  }

  save() {
    const ok = this.saves.write(this.captureState());
    this.onNotice(ok ? 'Saved.' : `Save failed: ${this.saves.lastError}`);
    return ok;
  }

  load() {
    const doc = this.saves.read();
    if (!doc) {
      this.onNotice(`Load failed: ${this.saves.lastError}`);
      return false;
    }
    return this.applyState(doc);
  }

  /// Restores a validated save.
  ///
  /// When the saved world is no longer available -- unpublished, renamed, withdrawn -- the
  /// player is put back in the starting world rather than refused. Their inventory is intact
  /// either way: losing what someone was carrying because a world went away is exactly the
  /// failure *Protection of existing work* forbids.
  applyState(doc) {
    this.createdAt = String(doc.created_at ?? nowUtc());
    this.catalog.loadSnapshot(doc.item_defs);
    this.inventory.fromSave(doc.inventory?.stacks);
    this.worldState = structuredClone(doc.world_state ?? {});

    const worldId = String(doc.player?.current_world ?? '');
    const at = coord(doc.player?.at);

    if (!this.registry.has(worldId)) {
      this.onNotice(`${worldId} is no longer installed. Returning to ${this.initialWorld}.`);
      const fellBack = this.goto(this.initialWorld, 'default');
      this.onNotice(fellBack ? 'Loaded.' : 'Load failed: no world left to return to.');
      return fellBack;
    }

    if (!this.goto(worldId, 'default')) return false;
    this.player.x = at.x;
    this.player.y = at.y;
    this.onNotice('Loaded.');
    return true;
  }
}
