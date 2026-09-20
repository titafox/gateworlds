// Keyboard on a desktop, a thumb on a phone.
//
// The stick appears wherever the thumb lands rather than in a fixed corner: a fixed stick is
// a thing you have to look down at, and looking down at a control is looking away from the
// game.

const KEYS = {
  ArrowLeft: [-1, 0], KeyA: [-1, 0],
  ArrowRight: [1, 0], KeyD: [1, 0],
  ArrowUp: [0, -1], KeyW: [0, -1],
  ArrowDown: [0, 1], KeyS: [0, 1],
};

const ACTIONS = new Set(['KeyI', 'F5', 'F9']);
const STICK_RADIUS = 48;

export class Controls {
  constructor(target, { onKey = () => {} } = {}) {
    this.held = new Set();
    this.touch = null;
    this.onKey = onKey;

    addEventListener('keydown', (e) => {
      if (e.repeat) return;
      if (e.code in KEYS) {
        this.held.add(e.code);
        e.preventDefault();
      } else if (ACTIONS.has(e.code)) {
        // F5 reloads the page and F9 is a devtools key. Saving with a key that throws the
        // page away instead would be a memorable bug.
        e.preventDefault();
        this.onKey(e.code);
      }
    });
    addEventListener('keyup', (e) => this.held.delete(e.code));
    addEventListener('blur', () => this.held.clear());

    const start = (e) => {
      const t = e.changedTouches[0];
      // The bottom right is for the buttons drawn over it; the rest of the screen is stick.
      if (t.clientX > innerWidth * 0.66 && t.clientY > innerHeight * 0.75) return;
      this.touch = { id: t.identifier, ox: t.clientX, oy: t.clientY, x: t.clientX, y: t.clientY };
      e.preventDefault();
    };
    const move = (e) => {
      if (!this.touch) return;
      for (const t of e.changedTouches) {
        if (t.identifier !== this.touch.id) continue;
        this.touch.x = t.clientX;
        this.touch.y = t.clientY;
        e.preventDefault();
      }
    };
    const end = (e) => {
      if (!this.touch) return;
      for (const t of e.changedTouches) if (t.identifier === this.touch.id) this.touch = null;
    };

    target.addEventListener('touchstart', start, { passive: false });
    target.addEventListener('touchmove', move, { passive: false });
    target.addEventListener('touchend', end);
    target.addEventListener('touchcancel', end);
  }

  /// The stick's origin and current point, for whatever wants to draw it. Null when idle.
  get stick() {
    return this.touch;
  }

  /// A direction of at most unit length. Diagonals are normalised, so walking at an angle is
  /// not faster than walking straight -- a bug old enough to have a name.
  direction() {
    let x = 0;
    let y = 0;

    for (const code of this.held) {
      const [dx, dy] = KEYS[code];
      x += dx;
      y += dy;
    }

    if (this.touch) {
      const dx = this.touch.x - this.touch.ox;
      const dy = this.touch.y - this.touch.oy;
      const len = Math.hypot(dx, dy);
      if (len > 6) {
        const scale = Math.min(len, STICK_RADIUS) / STICK_RADIUS / len;
        x += dx * scale;
        y += dy * scale;
      }
    }

    const len = Math.hypot(x, y);
    return len > 1 ? { x: x / len, y: y / len } : { x, y };
  }
}
