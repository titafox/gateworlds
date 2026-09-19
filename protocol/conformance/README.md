# Conformance vectors

These vectors are the executable form of [`../SPEC.md`](../SPEC.md). An implementation
claims conformance to protocol `0.1.0` by passing every one of them.

Passing these is also the operational definition of "replaceable" in
[ADR-0001 §3](../../docs/adr/0001-engine-neutrality.md): a new client or a new server is a
candidate the moment it passes, and no incumbent's agreement is required.

Both the Rust server validator and the Godot client validator run this same directory. Two
independent implementations agreeing is evidence of engine neutrality. One implementation
is just a habit.

## Vector format

One JSON file per vector:

```jsonc
{
  "$vector": {
    "kind": "world" | "items" | "save",
    "expect": "valid" | "invalid",
    "errors": [ { "code": "unknown_field", "path": "/entities/0/on_interact" } ],
    "exhaustive": false,
    "note": "why this vector exists"
  },
  "document": { /* the document under test */ }
}
```

- `kind` selects the schema and the procedural checks to apply.
- `path` is an RFC 6901 JSON Pointer into `document`. The empty string `""` points at the
  document root.
- `errors` is present only when `expect` is `"invalid"`.
- `exhaustive` defaults to `false`.

## Required runner behaviour

A conforming runner MUST:

1. For `expect: "valid"` — report **zero** errors. Any error is a failure.
2. For `expect: "invalid"` — report **every** `{code, path}` pair listed. A missing pair is
   a failure.
3. When `exhaustive` is `true` — report **no** pair beyond those listed.
4. When `exhaustive` is `false` (the default) — extra errors are tolerated. One broken
   field can legitimately cascade, and pinning every cascade would make the vectors
   brittle rather than useful.
5. Run every vector and report all failures. A runner that stops at the first failure hides
   the shape of a regression.

## Context a runner must supply

Some procedural checks need context the document alone does not carry. A vector states it
explicitly in `$vector.context`:

```jsonc
"context": {
  "world_id": "xianxia_gate",          // the defining world, for items.json vectors
  "items": ["all_components:thing"]    // item ids the runner should treat as defined
}
```

| Field | Default when absent | Used by |
|---|---|---|
| `world_id` | the document's own `id`, or `"w"` for `items` vectors | `invalid_item_namespace` |
| `items` | empty set | `unresolved_reference` on `pickup.item` |

The context is stated per vector and never inferred from `expect`. A runner that decided
how to validate by looking at the expected outcome would be arguing in a circle, and would
pass its own vectors no matter what the validator did.

`resource_not_found` is not exercised here — it needs a real package directory on disk, and
is covered by the shipped-package check below.

## Shipped packages must also validate

Separately from these vectors, CI MUST validate every world package under
[`../../worlds/`](../../worlds) with the full validator, including `resource_not_found`
and package-root containment. The reference worlds are content, not vectors; keeping them
out of this directory avoids two copies drifting apart.

## Adding a vector

A protocol change is not complete until it ships vectors. In practice:

- A new component type needs at least one valid vector and one vector proving the old
  validator rejects it (`unknown_component_type`), so version gating stays honest.
- A new error code needs at least one vector, or the two implementations have nothing
  holding them to the same taxonomy.
