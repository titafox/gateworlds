# Contributing

[English](CONTRIBUTING.md) — 中文 / Русский / 日本語 translations are welcome and are
themselves a good first contribution.

The thing this project most wants to find out is whether **someone else can create a world
and have it actually join this universe**. If you are here to do that, this document is for
you and it is short on purpose.

---

## A world is data

A world is a directory of JSON. There is no code in it, and there is no way to put code in
it — the protocol defines no field that carries a script, an expression, a shader or a path
to one, and unknown fields are rejected rather than ignored
([SPEC §9](protocol/SPEC.md)).

That is a limit on what you can express, and it is deliberate. It is also what makes it
possible to accept a world from a stranger.

## Quickstart

```sh
git clone https://github.com/titafox/gateworlds
cd gateworlds/server && cargo build --release && cd ..

mkdir -p worlds/my_world
# write worlds/my_world/world.json and items.json — copy the example below

./server/target/release/gateworlds-validate package worlds/my_world
```

The validator reports **every** problem it can find in one pass, so you are not fixing one
error per round trip:

```
  FAIL  worlds/my_world
      unresolved_reference         /entities/4/components/1/item
        "somewhere_else:pebble" is not defined in this package; in 0.1.0 a pickup must
        reference an item of its own package (SPEC §3.2)
      unknown_component_type       /entities/6/components/0/type
        "glow" is not in the component whitelist (sprite, solid, portal, pickup); the set
        is closed and adding to it is a protocol change (SPEC §7)
      duplicate_id                 /entities/6/id
        entity id "pebble" is already used at /entities/4
```

When it says `ok`, open a pull request. To see your world, run `godot --path client-godot`
and walk into it.

## A complete world to copy

One room, one thing to pick up, one way out.

This is not a sketch. The same files are in [`examples/my_world/`](examples/my_world), a
test validates them on every push, and a second test checks that what is printed here still
matches what is on disk — so this cannot quietly stop working as the protocol moves.

```sh
cp -r examples/my_world worlds/my_world
```

`worlds/my_world/world.json`:

```jsonc
{
  "protocol_version": "0.1.0",
  "id": "my_world",                       // must match the directory name
  "display_name": { "en": "My World", "zh-CN": "我的世界" },
  "description": { "en": "One room, one thing to pick up, one way out." },
  "license": { "code": "0BSD", "assets": "CC0-1.0" },
  "bounds": { "width": 320, "height": 240 },
  "background": "#202a35",
  "spawns": {
    "default": { "at": [40, 112] },       // every world needs "default"
    "from_village": { "at": [64, 112] }   // where arrivals from elsewhere land
  },
  "entities": [
    { "id": "wall_north", "at": [0, 0], "components": [
        { "type": "sprite", "size": [320, 16], "color": "#3b2f24", "z": -10 },
        { "type": "solid",  "size": [320, 16] } ] },
    { "id": "wall_south", "at": [0, 224], "components": [
        { "type": "sprite", "size": [320, 16], "color": "#3b2f24", "z": -10 },
        { "type": "solid",  "size": [320, 16] } ] },
    { "id": "wall_west", "at": [0, 0], "components": [
        { "type": "sprite", "size": [16, 240], "color": "#3b2f24", "z": -10 },
        { "type": "solid",  "size": [16, 240] } ] },
    { "id": "wall_east", "at": [304, 0], "components": [
        { "type": "sprite", "size": [16, 240], "color": "#3b2f24", "z": -10 },
        { "type": "solid",  "size": [16, 240] } ] },

    { "id": "pebble", "at": [180, 120], "components": [
        { "type": "sprite", "size": [12, 12], "color": "#c9c2b4", "z": 1 },
        { "type": "pickup", "size": [16, 16], "offset": [-2, -2],
          "item": "my_world:pebble" } ] },

    { "id": "way_out", "at": [256, 96], "components": [
        { "type": "sprite", "size": [40, 48], "color": "#9b7fe0", "z": 1 },
        { "type": "portal", "size": [40, 48],
          "target_world": "pastoral_village", "target_spawn": "default" } ] }
  ]
}
```

`worlds/my_world/items.json`:

```jsonc
{
  "protocol_version": "0.1.0",
  "items": [
    {
      "id": "my_world:pebble",            // items are namespaced by the world that defines them
      "display_name": { "en": "Pebble", "zh-CN": "石子" },
      "description": { "en": "Smooth, and warmer than it should be." },
      "icon": { "color": "#c9c2b4" },
      "stack_limit": 99,
      "props": { "weight_grams": 40 }     // opaque: yours to define, nobody else reads it
    }
  ]
}
```

Three things worth knowing before you start moving numbers around:

- **`at` is a top-left corner, not a centre** (SPEC §6.1). Everything is anchored that way.
- **A spawn must not sit inside a portal**, or arriving bounces you straight back out.
- **`props` is yours.** Put whatever your world means by an item in there — `spirit_qi`,
  `soil_moisture`, anything. No other world has to understand it, and no implementation is
  allowed to read it. That is how a world keeps its own rules without every other world
  having to agree (SPEC §1).

## Art

A `sprite` takes a colour or an image. [`docs/ART.md`](docs/ART.md) has the constraints the
renderers impose, the naming convention, and a prompt to start from if you are generating
textures. The short version: a texture is a **material**, not a picture of a thing, because
the browser client wraps it around all six faces of a box.

```sh
# drop images at worlds/<world>/art/<entity_id>.png, then
node scripts/wire-textures.mjs
./server/target/release/gateworlds-validate package worlds/*
```

## Writing a world with AI

This is the workflow the project is built around, so it is worth stating plainly:

1. Describe the world you want, in your own language.
2. Ask an AI to write `world.json` and `items.json`, giving it
   [`protocol/SPEC.md`](protocol/SPEC.md) and the example above.
3. Run the validator. Paste the errors back. Repeat.
4. Open it in the client and walk around.

The validator is what makes this work: it is precise about what is wrong and where, so the
loop closes without a human in it. **Do not submit output you have not run the validator on
and walked around in.** A world that has never been opened is not a world yet, whoever or
whatever wrote it.

## What is checked, and by whom

The split matters, because it is what keeps review fast and fair.

**The validator decides, and no reviewer overrides it.** Schema, version, the component
whitelist, resource paths, id uniqueness, reference resolution, item namespacing, bounds.
If it passes, nobody gets to call it badly formed; if it fails, no amount of goodwill
admits it. CI runs the same validator on your pull request.

**A person decides what a validator cannot:**

- **Provenance.** Do you have the right to contribute every asset, under the project's
  licences? An image you found is not an image you may contribute.
- **Name collisions.** Is the world id already taken, and is it a name that will still make
  sense to someone else?
- **Destinations.** Does your portal point somewhere that exists, or somewhere you have
  decided to leave dangling on purpose? Both are allowed (SPEC §7.3); which one you meant
  is not something a schema can tell.
- **Content.** Whether this belongs in a shared universe that strangers, including
  children, will walk into.

## When the protocol cannot express your world

This will happen, and it is the interesting case rather than a failure.

The component whitelist is closed: `sprite`, `solid`, `portal`, `pickup`. If your world
needs something else — a door that opens, a crop that grows, a creature that moves — you
cannot smuggle it in as data, and that is the point. Open an issue describing **what the
world needs**, not what field you would like to add.

Adding a component type costs: a schema change, conformance vectors proving the old
validator correctly rejects it, an implementation in the Rust validator and one in the
Godot client, and a protocol version bump with its migration note
([SPEC §2.3](protocol/SPEC.md)). That friction is the feature. It is the difference between
"worlds can do anything" and "worlds can be accepted from people you have never met".

## Licensing what you contribute

By opening a pull request you are contributing under the project's licences: **0BSD** for
code, **CC0 1.0** for art, music, worlds and documents.

There is no CLA and no copyright assignment — there is nothing to sign, and nothing for
anyone to inherit. See [README, *License*](README.md#-license) and
[`docs/SUCCESSION.md`](docs/SUCCESSION.md) §2.1 for why that is a continuity decision and
not only a generous one.

You must have the right to contribute what you send. Do not submit third-party code or
assets you cannot license this way, and do not submit anyone's personal data.

## Other ways in

- **Translations.** The README ships in four languages; this file ships in one. Translating
  it is a real contribution, not a warm-up.
- **The client, the validator, the protocol.** Same pull request flow. Tests are expected;
  see [`docs/BOOTSTRAP.md`](docs/BOOTSTRAP.md) for how to run everything.
- **Bugs and rough edges.** Open an issue. "I could not work out how to X from the docs" is
  a bug report.
- **The rules themselves.** [`CONSTITUTION.md`](CONSTITUTION.md) is a draft, and amending it
  is a contribution like any other.

## What to expect

One maintainer, reviewing in their own time. A pull request may sit for a while. If it has
been two weeks and nothing has happened, say so on the thread — that is not rude, it is
the system working.

When the review is slow, the licences mean you are never blocked: everything here is 0BSD
and CC0, so you can run your own copy, with your world in it, without asking anyone.
