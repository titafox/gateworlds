# Gateworlds — World Protocol

**Version:** `0.1.0`
**Status:** Draft. Pre-1.0 — minor versions may break compatibility (see §2).
**Normative.** This directory defines the contract. `client-godot/` and `server/` are
implementations of it and have no authority to extend it. See
[`../docs/adr/0001-engine-neutrality.md`](../docs/adr/0001-engine-neutrality.md).

The key words MUST, MUST NOT, SHOULD, SHOULD NOT and MAY are to be interpreted as in
RFC 2119.

---

## 1. Design constraints

These follow from the project constitution and are not negotiable inside a protocol
version:

1. **No gameplay in the protocol.** The protocol knows about worlds, entities,
   components, items, portals and inventory. It does not know about levels, hit points,
   attack power, farming, cultivation, or any genre. No such field is defined, and no
   world may require one of another world.
2. **Open property bags.** Worlds, entities and items each carry a `props` object with
   arbitrary, creator-defined content. **No conforming implementation may read, validate,
   interpret or require any key inside `props`.** It is carried and persisted verbatim.
   This is where a world puts `spirit_qi`, `soil_moisture`, or anything else, without
   every other world having to agree.
3. **Data only. No code.** A world package is data. There is no field anywhere in this
   protocol that carries a script, an expression, a formula, a shader, a query, a
   template, or a path to any of those. See §9.
4. **Engine-neutral.** No field is named after, or shaped by, any engine's types.
5. **Versioned with room to migrate.** Every document carries a version, and every
   version bump carries a migration obligation (§2.3).

---

## 2. Versioning

### 2.1 Format

`protocol_version` and `save_version` are semantic version strings: `MAJOR.MINOR.PATCH`,
each a non-negative integer with no leading zeros, no pre-release or build metadata.

### 2.2 Acceptance rule

An implementation that implements version `X.Y.Z` MUST apply exactly this rule to a
document declaring `A.B.C`:

| Condition | Result | Error code |
|---|---|---|
| `A != X` | Reject | `unsupported_protocol_version` |
| `X == 0` and `B != Y` | Reject | `unsupported_protocol_version` |
| `X > 0` and `B > Y` | Reject | `unsupported_protocol_version` |
| `X > 0` and `B <= Y` | Accept | — |
| `C` differs | Ignore `C` | — |

Pre-1.0 (`MAJOR == 0`), the minor version is treated as breaking. This is deliberate: a
`0.1` implementation MUST NOT silently accept a `0.2` package it does not understand.

### 2.3 Migration obligation

This is the technical form of the constitutional principle *Protection of existing work*.

- Every **minor** bump before 1.0 MUST ship a written migration note in
  `protocol/migrations/<from>-to-<to>.md` describing every changed field and how to
  convert an existing document.
- Every **major** bump MUST ship either an automated converter or a documented rollback
  path kept available for at least one release cycle.
- A version bump submitted without its migration artefact is not a valid proposal.

`protocol/migrations/` is empty at `0.1.0` because there is nothing to migrate from. The
directory exists so that the obligation is visible rather than remembered.

---

## 3. Identifiers

### 3.1 Slugs

A **slug** matches `^[a-z0-9]([a-z0-9_]*[a-z0-9])?$`, is 1–64 characters, and is compared
byte-for-byte (no case folding, no Unicode normalisation — both are sources of
impersonation bugs).

World ids and entity ids are slugs. Entity ids MUST be unique within their world package.

### 3.2 Item ids are namespaced

An **item id** is `<world_id>:<slug>`, e.g. `xianxia_gate:spirit_herb`.

- A world package MUST NOT define an item whose namespace is not its own world id.
- Namespacing makes item ids globally unique without a central allocator, and makes the
  origin of a cross-world item readable at a glance.
- In `0.1.0`, a `pickup` component MUST reference an item defined in the same package
  (error `unresolved_reference` otherwise). Granting foreign items is deferred to a later
  version; the id format already allows it.

### 3.3 Spawn names

Spawn point names are slugs. Every world MUST define a spawn named `default`.

---

## 4. Localised text

A **LocalizedText** is a JSON object mapping a BCP-47 language tag to a string. At least
one entry is required. No specific language is mandated — requiring English would exclude
creators the project is trying to include.

Resolution order, which every implementation MUST follow so that two clients show the same
string:

1. Exact match on the user's locale tag (e.g. `zh-CN`).
2. The primary subtag of the user's locale (e.g. `zh`), or any entry whose primary subtag
   matches, choosing the lexicographically smallest tag among matches.
3. `en`, if present.
4. The lexicographically smallest key present.

Step 4 guarantees the result is deterministic and never empty.

---

## 5. Resource paths

A **ResourcePath** is a string naming a file inside the world package.

It MUST satisfy all of:

- matches `^[A-Za-z0-9_][A-Za-z0-9_\-./]*$`
- is 1–255 characters
- contains no `..` path segment
- does not start with `/`
- contains no `\`, no `:`, and no `//`
- does not end with `/` or `.`
- after resolution against the package root, the real path is inside the package root

The character restrictions reject engine schemes (`res://`, `user://`), Windows absolute
paths (`C:\`), URLs (`https://`) and UNC paths by construction rather than by blacklist.

Implementations MUST resolve symlinks before the containment check, and MUST reject a path
that resolves outside the package root even if the literal string looked fine
(`invalid_resource_path`). A path that passes validation but names a missing file is
`resource_not_found`.

---

## 6. World package

A world package is a directory containing:

| File | Required | Schema |
|---|---|---|
| `world.json` | yes | [`world-v0.1.schema.json`](world-v0.1.schema.json) |
| `items.json` | no | [`items-v0.1.schema.json`](items-v0.1.schema.json) |
| other files | no | referenced only via ResourcePath |

### 6.1 `world.json`

```jsonc
{
  "protocol_version": "0.1.0",
  "id": "xianxia_gate",
  "display_name": { "zh-CN": "青霄山门", "en": "Azure Sky Gate" },
  "description": { "en": "A small mountain sect." },       // optional
  "authors": [ { "name": "somebody", "contact": "..." } ], // optional
  "license": { "code": "0BSD", "assets": "CC0-1.0" },      // optional
  "bounds": { "width": 640, "height": 480 },
  "background": "#1b2430",                                  // optional
  "spawns": {
    "default":        { "at": [96, 96] },
    "from_village":   { "at": [64, 288] }
  },
  "entities": [ /* §6.2 */ ],
  "props": {}                                               // optional, opaque
}
```

`bounds` is in abstract protocol units, origin top-left, x right, y down. Units are not
pixels and not metres; a client maps them to its own space. Both dimensions are integers
in `[1, 100000]`.

Coordinates are `[x, y]` integer pairs. A spawn or entity position outside `bounds` is
`value_out_of_range`.

**Anchoring.** An entity's `at` is its **top-left origin**, not its centre. A component's
rectangle spans from `at + offset` to `at + offset + size`, where `offset` defaults to
`[0, 0]`. Every implementation MUST use this convention, so that a package places
identically on any client. Choosing centre-anchoring in one client and top-left in another
is exactly the kind of silent divergence the conformance vectors exist to prevent.

### 6.2 Entities

```jsonc
{
  "id": "herb_1",
  "at": [320, 160],
  "props": {},                 // optional, opaque
  "components": [ /* §7 */ ]   // 1 or more
}
```

An entity is a position plus a list of components. It has no other behaviour and no
implicit attributes.

---

## 7. Component whitelist

A component is `{ "type": <name>, ...parameters }`. **The set of types is closed.** A type
not in this table is `unknown_component_type` — an implementation MUST NOT load the
package, and MUST NOT skip the component and continue.

Adding a type is a protocol change and goes through governance. This is the mechanism by
which expressive power grows: reviewed engine code, referenced by name from data.

An entity MUST NOT carry two components of the same `type`.

### 7.1 `sprite` — visual representation

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | `"sprite"` | yes | |
| `size` | `[w, h]` | yes | integers in `[1, 100000]` |
| `color` | `#rrggbb` or `#rrggbbaa` | one of | lowercase hex |
| `texture` | ResourcePath | one of | |
| `z` | integer | no | `[-1000, 1000]`, default `0`; draw order |

Exactly one of `color` / `texture` MUST be present.

### 7.2 `solid` — blocks movement

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | `"solid"` | yes | |
| `size` | `[w, h]` | yes | integers in `[1, 100000]` |
| `offset` | `[x, y]` | no | default `[0, 0]`, relative to entity position |

### 7.3 `portal` — travel to another world

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | `"portal"` | yes | |
| `size` | `[w, h]` | yes | trigger area |
| `offset` | `[x, y]` | no | default `[0, 0]` |
| `target_world` | world id slug | yes | |
| `target_spawn` | spawn slug | no | default `"default"` |

A portal names a destination. It does not describe how travel happens; that is the
client's business. `target_world` MAY name a world not present locally — resolution
happens at travel time, not at validation time, so that a package stays valid on its own.

### 7.4 `pickup` — grants an item when collected

| Field | Type | Required | Notes |
|---|---|---|---|
| `type` | `"pickup"` | yes | |
| `size` | `[w, h]` | yes | trigger area |
| `offset` | `[x, y]` | no | default `[0, 0]` |
| `item` | item id | yes | MUST be defined in this package (§3.2) |
| `count` | integer | no | `[1, 9999]`, default `1` |
| `once` | boolean | no | default `true`; if true, consumed permanently per save |

`pickup` is a generic mechanic, not a genre. A spirit herb, a carrot and a data shard are
all the same component with different item ids.

---

## 8. Items

### 8.1 `items.json`

```jsonc
{
  "protocol_version": "0.1.0",
  "items": [
    {
      "id": "xianxia_gate:spirit_herb",
      "display_name": { "zh-CN": "灵草", "en": "Spirit Herb" },
      "description": { "en": "A faintly glowing herb." },   // optional
      "icon": { "color": "#7fe08a" },                        // or { "texture": ... }
      "stack_limit": 99,                                     // optional, [1,9999], default 99
      "props": { "spirit_qi": 3 }                            // optional, opaque
    }
  ]
}
```

`props` is where world-specific meaning lives. The village world does not know what
`spirit_qi` is, and is not required to. It carries the value unchanged.

### 8.2 The item catalog is universe-scoped

Inventory is a property of the player, not of a world. When the player carries
`xianxia_gate:spirit_herb` into `pastoral_village`, the village package contains no
definition for it.

Implementations MUST resolve an item definition in this order:

1. The catalog assembled from currently known world packages.
2. The definition snapshot embedded in the save (§8.3).

If neither resolves, the stack MUST still be preserved and persisted, rendered with a
placeholder. **Losing a player's item because its defining world is unavailable is a
breach of *Protection of existing work* and MUST NOT happen.**

### 8.3 Saves embed a definition snapshot

A save MUST embed a copy of the definition of every item it holds a stack of. This makes
a save self-contained: it survives a world package being unpublished, renamed or deleted.
The live catalog takes precedence when present, so a world author can still fix a typo in
an item name.

---

## 9. Explicitly forbidden constructs

None of the following exist in this protocol, and a document containing any of them MUST
be rejected by `unknown_field` (they are not defined) or by the path rules in §5:

- script source, bytecode, or a path to either
- expressions, formulae, or conditions in string form
- shader source, or paths to shaders
- SQL, template languages, or any other evaluated string
- absolute filesystem paths, engine URI schemes, or network URLs
- references to files outside the package

Every schema in this directory sets `additionalProperties: false`. An unrecognised field
is an error, never a silently ignored extension. Combined with the version gate in §2.2,
this means an implementation never guesses about content it does not understand.

---

## 10. Save format

See [`save-v0.1.schema.json`](save-v0.1.schema.json).

```jsonc
{
  "save_version": "0.1.0",
  "created_at": "2026-09-19T03:00:00Z",       // RFC 3339, UTC
  "updated_at": "2026-09-19T03:12:41Z",
  "player": {
    "current_world": "pastoral_village",
    "at": [128, 200],
    "props": {}                                // optional, opaque
  },
  "inventory": {
    "stacks": [
      { "item": "xianxia_gate:spirit_herb", "count": 1, "props": {} }
    ]
  },
  "item_defs": {                               // §8.3 snapshot
    "xianxia_gate:spirit_herb": { /* an item object, §8.1 */ }
  },
  "world_state": {
    "xianxia_gate": {
      "consumed_pickups": ["herb_1"],
      "props": {}
    }
  }
}
```

- `inventory.stacks` is ordered; the order is the player's slot order and MUST be
  preserved across save/load.
- Two stacks MAY share an `item` id (a split stack). Implementations MUST NOT silently
  merge them.
- `world_state` keys are world ids. `consumed_pickups` holds entity ids whose `once`
  pickup has been taken.
- Writing a save MUST be atomic: write a temporary file in the same directory, flush, then
  rename over the target. A partially written save is worse than an old save.

---

## 11. Validation error taxonomy

Both the server and the client validator MUST report these codes. The conformance vectors
in `conformance/invalid/` assert on them, so the two implementations are held to the same
taxonomy.

| Code | Meaning |
|---|---|
| `schema_violation` | Fails the JSON Schema (wrong type, missing required field, bad pattern) |
| `unsupported_protocol_version` | Version rule §2.2 rejects the document |
| `unknown_component_type` | `type` is not in the §7 whitelist |
| `unknown_field` | A field not defined by the schema is present |
| `invalid_resource_path` | Fails the §5 path rules |
| `resource_not_found` | A valid path names a file that is not in the package |
| `duplicate_id` | Two entities, items or spawns share an id, or an entity carries two components of the same `type` |
| `unresolved_reference` | A reference cannot be resolved (e.g. `pickup.item`) |
| `invalid_item_namespace` | An item id's namespace is not the defining world's id |
| `value_out_of_range` | A numeric value is outside its documented range |

A validator MUST report **all** errors it can find, not only the first. A creator fixing
one error at a time through a slow review loop is a bad experience, and a bad experience
means fewer worlds.

Where more than one code could apply, the more specific one wins: `unknown_component_type`
over `schema_violation`, `invalid_item_namespace` over `schema_violation`,
`value_out_of_range` over `schema_violation`.

---

## 12. Conformance

An implementation claims conformance to `0.1.0` by passing every vector in
[`conformance/`](conformance/). See [`conformance/README.md`](conformance/README.md) for
the vector format and the required runner behaviour.

Passing the vectors is what "replaceable" means in practice — see ADR-0001 §3.
