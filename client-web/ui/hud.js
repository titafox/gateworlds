// What the player can see, as DOM over the canvas.
//
// The same two ideas as the Godot client's HUD, because they are about this project rather
// than about a toolkit:
//
//   The panel takes its colour from the world you are standing in. In a universe of worlds,
//   an interface that says where you are is worth more than one with a house style.
//
//   Each stack says which world it came from. Items are namespaced by their defining world,
//   and when things travel between worlds, where a thing is from is the interesting fact
//   about it -- more interesting than its count.

const MIN_SEPARATION = 0.055;

const luminance = ({ r, g, b }) => 0.2126 * r + 0.7152 * g + 0.0722 * b;

export const toRgb = (hex) => ({
  r: ((hex >> 16) & 255) / 255,
  g: ((hex >> 8) & 255) / 255,
  b: (hex & 255) / 255,
});

export const css = ({ r, g, b }) =>
  `rgb(${Math.round(r * 255)} ${Math.round(g * 255)} ${Math.round(b * 255)})`;

const darken = (c, k) => ({ r: c.r * k, g: c.g * k, b: c.b * k });
const lighten = (c, k) => ({
  r: c.r + (1 - c.r) * k,
  g: c.g + (1 - c.g) * k,
  b: c.b + (1 - c.b) * k,
});

/// The panel colour for a world: its own background, pushed until it separates.
///
/// Darkening alone is not enough. A world that is already nearly black has nowhere darker to
/// go, so the panel lands within a few percent of the ground and the interface dissolves
/// into it. When there is no room below, it goes up instead. A community world can be any
/// colour, so this is derived and checked rather than assumed.
export function panelFor(hex) {
  const base = toRgb(hex);
  const down = darken(base, 0.45);
  if (Math.abs(luminance(base) - luminance(down)) >= MIN_SEPARATION) return down;
  return lighten(base, 0.22);
}

export function textOn(panel) {
  return luminance(panel) > 0.5 ? { r: 0.08, g: 0.09, b: 0.11 } : { r: 0.91, g: 0.89, b: 0.85 };
}

export function dimOn(panel) {
  return luminance(panel) > 0.5 ? { r: 0.35, g: 0.38, b: 0.41 } : { r: 0.5, g: 0.53, b: 0.58 };
}

export class Hud {
  constructor(root) {
    this.root = root;
    this.worldEl = root.querySelector('#world-name');
    this.panelEl = root.querySelector('#inventory');
    this.rowsEl = root.querySelector('#rows');
    this.noticeEl = root.querySelector('#notice');
    this.open = false;
    this.noticeTimer = 0;
  }

  setWorld(name, backgroundHex) {
    const panel = panelFor(backgroundHex);
    this.root.style.setProperty('--panel', css(panel));
    this.root.style.setProperty('--text', css(textOn(panel)));
    this.root.style.setProperty('--dim', css(dimOn(panel)));
    // Hints sit on the world, not on a panel, so their contrast comes from the world.
    this.root.style.setProperty('--hint', css(dimOn(toRgb(backgroundHex))));
    this.worldEl.textContent = name;
  }

  toggleInventory() {
    this.open = !this.open;
    this.panelEl.classList.toggle('open', this.open);
  }

  setRows(rows) {
    this.rowsEl.replaceChildren();
    if (rows.length === 0) {
      // An empty panel is an invitation to act, not a statement of fact.
      const empty = document.createElement('div');
      empty.className = 'empty';
      const line = document.createElement('span');
      line.textContent = 'Nothing yet.';
      const hint = document.createElement('small');
      hint.textContent = 'Walk over things.';
      empty.append(line, hint);
      this.rowsEl.append(empty);
      return;
    }
    for (const row of rows) {
      const el = document.createElement('div');
      el.className = 'row';
      const icon = document.createElement('i');
      icon.style.background = row.icon;
      const name = document.createElement('span');
      name.textContent = row.name;
      const origin = document.createElement('small');
      origin.textContent = row.origin;
      const count = document.createElement('b');
      count.textContent = row.count;
      el.append(icon, name, count, origin);
      this.rowsEl.append(el);
    }
  }

  /// Says what changed, in the same words as the action that changed it.
  notice(text) {
    this.noticeEl.textContent = text;
    this.noticeEl.classList.add('show');
    clearTimeout(this.noticeTimer);
    this.noticeTimer = setTimeout(() => this.noticeEl.classList.remove('show'), 2400);
  }
}
