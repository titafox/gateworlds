// Turning protocol coordinates into scene coordinates, in one place.
//
// SPEC §6.1: an entity's `at` is its **top-left origin**, not its centre, and a component's
// rectangle spans `at + offset` to `at + offset + size`.
//
// three.js positions a box by its centre, so every component has to convert. Doing that
// inline in four places is four chances to get it wrong in a way nothing reports -- the
// package would simply lay out differently here than in the Godot client, with no error
// anywhere. It lives here, with tests.

export function coord(value) {
  if (!Array.isArray(value) || value.length < 2) return { x: 0, y: 0 };
  return { x: Number(value[0]) || 0, y: Number(value[1]) || 0 };
}

export function size(value) {
  if (!Array.isArray(value) || value.length < 2) return { w: 1, h: 1 };
  return { w: Number(value[0]) || 1, h: Number(value[1]) || 1 };
}

/// The component's rectangle in world coordinates, top-left anchored.
export function rectFor(at, offset, sz) {
  return { x: at.x + offset.x, y: at.y + offset.y, w: sz.w, h: sz.h };
}

/// Where to put a centred box so that it covers `rectFor(...)`.
export function centreOf(rect) {
  return { x: rect.x + rect.w / 2, y: rect.y + rect.h / 2 };
}

export function rectsOverlap(a, b) {
  return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

/// `#rrggbb` / `#rrggbbaa` to a 0xRRGGBB integer and an alpha, as three.js wants them.
export function color(value, fallback = 0xff00ff) {
  if (typeof value !== 'string' || !value.startsWith('#')) return { hex: fallback, alpha: 1 };
  const body = value.slice(1);
  if (body.length !== 6 && body.length !== 8) return { hex: fallback, alpha: 1 };
  return {
    hex: parseInt(body.slice(0, 6), 16),
    alpha: body.length === 8 ? parseInt(body.slice(6, 8), 16) / 255 : 1,
  };
}

/// SPEC §4 resolution order, so that every client shows the same string: exact locale, then
/// primary subtag (lexicographically smallest match), then `en`, then the lexicographically
/// smallest key. The last step is what guarantees a result at all.
export function localized(value, locale, fallback) {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return fallback;
  const keys = Object.keys(value).sort();
  if (keys.length === 0) return fallback;
  if (locale in value) return value[locale];

  const primary = locale.split('-')[0];
  for (const k of keys) if (k.split('-')[0] === primary) return value[k];
  if ('en' in value) return value.en;
  return value[keys[0]];
}
