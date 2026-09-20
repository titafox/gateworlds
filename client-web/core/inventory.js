// What the player is carrying.
//
// Belongs to the player, not to a world. Nothing here is cleared when a world is swapped,
// which is why the spirit herb survives the walk back to the village: not a special case,
// simply the absence of one.

const sameProps = (a, b) => JSON.stringify(a) === JSON.stringify(b);

export class Inventory {
  constructor() {
    /// Ordered. SPEC §10: this is the player's slot order and must be preserved across
    /// save/load. Each entry is { item, count, props }.
    this.stacks = [];
    this.onChange = () => {};
  }

  get isEmpty() {
    return this.stacks.length === 0;
  }

  clear() {
    this.stacks = [];
    this.onChange();
  }

  total(itemId) {
    return this.stacks.reduce((n, s) => (s.item === itemId ? n + s.count : n), 0);
  }

  /// Fills existing stacks before opening new ones.
  ///
  /// Only a stack with the *same* props is filled. Merging two stacks that differ in props
  /// would quietly destroy whatever distinguished them, and props are opaque -- this code
  /// has no way to know what it would be throwing away.
  add(itemId, count, limit = 99, props = {}) {
    if (count <= 0) return;
    let remaining = count;
    const cap = Math.max(1, limit);

    for (const s of this.stacks) {
      if (remaining <= 0) break;
      if (s.item === itemId && sameProps(s.props, props) && s.count < cap) {
        const moved = Math.min(cap - s.count, remaining);
        s.count += moved;
        remaining -= moved;
      }
    }
    while (remaining > 0) {
      const chunk = Math.min(cap, remaining);
      this.stacks.push({ item: itemId, count: chunk, props: structuredClone(props) });
      remaining -= chunk;
    }
    this.onChange();
  }

  /// The shape SPEC §10 stores. Props are written only when non-empty, so a save does not
  /// fill with noise.
  toSave() {
    return this.stacks.map((s) => {
      const entry = { item: s.item, count: s.count };
      if (Object.keys(s.props).length > 0) entry.props = structuredClone(s.props);
      return entry;
    });
  }

  /// Restores exactly what was saved.
  ///
  /// SPEC §10: two stacks may share an item id, and an implementation **must not** silently
  /// merge them. So this appends verbatim and never calls add().
  fromSave(entries) {
    this.stacks = (Array.isArray(entries) ? entries : [])
      .filter((e) => typeof e === 'object' && e !== null)
      .map((e) => ({
        item: String(e.item ?? ''),
        count: Number(e.count ?? 1),
        props: typeof e.props === 'object' && e.props !== null ? structuredClone(e.props) : {},
      }));
    this.onChange();
  }

  /// Every distinct item id held, for building the save's definition snapshot.
  itemIds() {
    return [...new Set(this.stacks.map((s) => s.item))].sort();
  }
}
