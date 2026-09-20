// Item definitions, for the whole universe rather than for one world.
//
// SPEC §8.2. When the player carries `xianxia_gate:spirit_herb` into `pastoral_village`, the
// village package contains no definition for it. Resolution looks in the live catalog first
// and in the save's embedded snapshot second -- and when neither has it, the stack is still
// kept and rendered as a placeholder.
//
// **Losing a player's item because its defining world is unavailable is a breach of
// *Protection of existing work* and must not happen.** That is why this has two layers.

import { localized } from './world/geometry.js';

export const PLACEHOLDER_COLOR = '#8a8a8a';

export class ItemCatalog {
  constructor() {
    this.live = new Map();
    this.snapshot = new Map();
  }

  loadFromRegistry(registry) {
    this.live.clear();
    for (const id of registry.ids) {
      for (const item of registry.itemsDoc(id)?.items ?? []) {
        if (typeof item?.id === 'string') this.live.set(item.id, item);
      }
    }
  }

  loadSnapshot(itemDefs) {
    this.snapshot.clear();
    if (typeof itemDefs !== 'object' || itemDefs === null) return;
    for (const [id, def] of Object.entries(itemDefs)) {
      if (typeof def === 'object' && def !== null) this.snapshot.set(id, def);
    }
  }

  /// The live catalog wins, so a world author can fix a typo in an item's name and have it
  /// take effect on saves written before the fix.
  resolve(itemId) {
    return this.live.get(itemId) ?? this.snapshot.get(itemId) ?? null;
  }

  isKnown(itemId) {
    return this.resolve(itemId) !== null;
  }

  displayName(itemId, locale = 'en') {
    const def = this.resolve(itemId);
    return def ? localized(def.display_name, locale, itemId) : itemId;
  }

  iconColor(itemId) {
    const icon = this.resolve(itemId)?.icon;
    return typeof icon?.color === 'string' ? icon.color : PLACEHOLDER_COLOR;
  }

  stackLimit(itemId) {
    return Number(this.resolve(itemId)?.stack_limit ?? 99);
  }

  /// SPEC §8.3: a save embeds the definition of every item it holds a stack of, so that it
  /// survives its defining world being unpublished, renamed or deleted.
  snapshotFor(itemIds) {
    const out = {};
    for (const id of itemIds) {
      // Already unresolvable: a minimal stand-in keeps the save schema-valid and the stack
      // loadable, rather than dropping the player's item to keep the file tidy.
      out[id] = this.resolve(id) ?? {
        id,
        display_name: { en: id },
        icon: { color: PLACEHOLDER_COLOR },
      };
    }
    return out;
  }
}
