// Turning a validated world document into the flat lists the game and the renderer need.
//
// The loader never reads a path, a class name or a script reference out of a document. The
// only thing it takes from data is a component *type name*, matched against a fixed set.
// That is the whole trust boundary: a world says what it wants, the client decides what that
// means.

import { centreOf, color, coord, rectFor, size } from './geometry.js';

/// The closed component whitelist, SPEC §7. A type outside the set never reaches here,
/// because validation rejects the package first.
const HANDLED = new Set(['sprite', 'solid', 'portal', 'pickup']);

/// `world` must already have passed validation -- see Registry. Passing an unvalidated
/// document here is a programming error, not a user error, so the loader does not re-check.
///
/// `consumed` lists entity ids whose `once` pickup has already been taken in this save.
/// Those entities are not built at all, matching what happens at runtime when one is
/// collected: the whole entity goes, not just its pickup.
export function buildRuntime(world, consumed = [], assets = new Map()) {
  const skip = new Set(consumed);
  const runtime = {
    worldId: world.id,
    world,
    bounds: { w: world.bounds?.width ?? 640, h: world.bounds?.height ?? 480 },
    background: color(world.background, 0x101418),
    visuals: [],
    solids: [],
    portals: [],
    pickups: [],
  };

  for (const entity of world.entities ?? []) {
    const entityId = String(entity.id ?? '');
    if (skip.has(entityId)) continue;

    const at = coord(entity.at);
    const components = entity.components ?? [];
    // A thing that blocks you should look like it blocks you. `solid` is a semantic the
    // protocol defines, so standing those entities up is a faithful reading of the data
    // rather than an invention of this client's.
    const blocks = components.some((c) => c?.type === 'solid');

    for (const component of components) {
      const type = component?.type;
      if (!HANDLED.has(type)) continue;

      const rect = rectFor(at, coord(component.offset), size(component.size));
      const centre = centreOf(rect);

      if (type === 'sprite') {
        runtime.visuals.push({
          entityId, rect, centre, blocks,
          ...color(component.color, 0xff00ff),
          z: Number(component.z ?? 0),
          // Only a verified asset becomes a URL; an unresolved path stays null and the
          // renderer falls back to the colour rather than silently drawing nothing.
          texture: typeof component.texture === 'string'
            ? (assets.get(component.texture) ?? null)
            : null,
        });
      } else if (type === 'solid') {
        runtime.solids.push({ entityId, rect });
      } else if (type === 'portal') {
        runtime.portals.push({
          entityId, rect,
          targetWorld: String(component.target_world ?? ''),
          targetSpawn: String(component.target_spawn ?? 'default'),
        });
      } else if (type === 'pickup') {
        runtime.pickups.push({
          entityId, rect,
          item: String(component.item ?? ''),
          count: Number(component.count ?? 1),
          once: component.once !== false,
        });
      }
    }
  }
  return runtime;
}
