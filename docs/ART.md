# Art for worlds

At protocol 0.1.0 a world's whole visual vocabulary is the `sprite` component: an
axis-aligned rectangle that is **either** a flat colour **or** an image
([SPEC §7.1](../protocol/SPEC.md)). There are no sprites-with-transparency-over-a-scene, no
layers beyond `z`, no rotation and no animation.

That is a tight brief, and it decides what the art has to be.

## What a texture actually becomes

| Client | What it does with your image |
|---|---|
| `client-web` | Wraps it around a box — all six faces, same image |
| `client-godot` | Fills the rectangle, flat |

So a texture is a **material**, not a picture of a thing. "Rammed earth", "thatch",
"weathered stone", "still water" all work. "A house seen from three-quarters above" does
not: in the browser it lands on the sides of a box as well as the top, and in the Godot
client it is squashed into whatever rectangle the world declared.

Rules that follow from that:

- **Seamless.** A rectangle can be any size; a texture that tiles cleanly survives being
  stretched across a 640-unit wall.
- **No perspective, no cast shadows, no ground line.** The renderer lights the box. A
  texture that already contains lighting fights it.
- **No text and no logos.** They end up mirrored on the far face of a box, and they cannot
  be translated — this project ships in four languages and a picture of a word ships in one.
- **Flat, even value.** Reserve contrast for the thing itself, not for a highlight that will
  appear on all six sides at once.
- **Square, 256×256 or 512×512, PNG.** Larger buys nothing: things are small on screen and a
  phone pays for every pixel.

## Naming and wiring

An image belongs to an entity, by id:

```
worlds/<world_id>/art/<entity_id>.png
```

Then:

```sh
node scripts/wire-textures.mjs
./server/target/release/gateworlds-validate package worlds/*
```

The script swaps that sprite's `color` for `texture`. It only goes one way; to undo, use
`git checkout worlds/`.

A texture the validator cannot find is `resource_not_found` and the package is refused —
there is no "use it if it is there". That rule caught a stale reference during development
about ten seconds after the file was deleted, which is the argument for it.

## Licensing

Art is **CC0 1.0** (README, *License*). You must have the right to release it that way.

If you generate it: in the United States a purely machine-generated image is not
copyrightable, which makes CC0 an accurate description rather than a claim. Other
jurisdictions differ, and a model's terms of service are a separate matter from copyright —
check the terms of whatever you used. Do not feed it someone else's characters or art and
contribute the result.

## A prompt to start from

Generated art tends to arrive with lighting, perspective and a subject baked in — the three
things this brief cannot use. The negatives below are doing most of the work.

```
A seamless tileable top-down texture of {MATERIAL}.
Flat even lighting, no cast shadows, no highlights, no gradients across the tile.
Orthographic, straight down, no perspective, no horizon, no ground line.
Hand-painted ink-wash feel, muted, slightly desaturated.
Dominant colour {HEX}. Keep the whole tile within one value range.
Square, edge-to-edge, seamless on all four sides.
No text, no characters, no letters, no logos, no borders, no frame,
no vignette, no drop shadow, no 3D render, no isometric view, no single object
centred in the frame.
```

Fill `{MATERIAL}` and `{HEX}` from the table below. The hexes are the colours those entities
use today, so a texture built around them drops in without the world looking re-lit.

### 月麓村 `yuelu_village` — a mortal village, dust and dry grass

| Entity | Material | Hex |
|---|---|---|
| `hut_west` `hut_south` `hut_east` | rammed earth wall, straw fibres in the mud, cracked | `#6b5640` |
| `thatch_west` `thatch_east` | dry rice straw thatch, bundled, weathered grey-gold | `#8a7648` |
| `well` | wet dark stone rim, moss in the joints | `#3a4a55` |
| `cart_track` | packed dirt track, faint wheel ruts | `#5a5344` |
| `wall_n` `wall_s` `wall_w` `wall_e` | old mud-brick boundary wall | `#4a4038` |

### 登云道 `cloud_stair` — seven hundred steps in mist

| Entity | Material | Hex |
|---|---|---|
| `cliff_west` `cliff_east` | wet granite cliff face, vertical fracture lines | `#3c4650` |
| `step_0` … `step_6` | worn stone stair tread, hollowed in the middle | `#7c8894` |
| `pine` `pine_2` | dense dark pine canopy from above | `#2d4536` |

### 岐峰门 `qifeng_gate` — the gate of a minor sect

| Entity | Material | Hex |
|---|---|---|
| `pillar_west` `pillar_east` | carved grey granite column, faint cloud pattern | `#8a8f98` |
| `lintel` | dark stone beam, chiselled | `#6d737c` |
| `plaque` | polished green jade, cloudy veining | `#5fa08a` |
| `bell` | patinated bronze, verdigris in the recesses | `#8a6a3a` |
| `stone_lion_w` `stone_lion_e` | weathered carved stone | `#6d737c` |

### 灵田 `spirit_field` — terraced spirit-herb fields

| Entity | Material | Hex |
|---|---|---|
| `terrace_0` … `terrace_4` | turned dark loam with young green shoots | `#234a2c` |
| `channel` | shallow still irrigation water, faint reflection | `#2f5d7a` |
| `stone_edge_north` `stone_edge_south` | dry-stacked field stones | `#3d4a34` |
| `shed` | weathered timber planks | `#4a4038` |

### Portals

The portal purple `#9b7fe0` is the one colour used across every world for the same meaning.
If you texture it, texture all of them the same way, or it stops meaning anything:

| Entity | Material | Hex |
|---|---|---|
| any portal | faintly glowing violet talisman paper, seal script strokes dissolving at the edges | `#9b7fe0` |

## What the protocol cannot do yet

Worth knowing before you draw for it:

- **No transparency that matters.** A sprite is a filled rectangle; there is no cut-out shape.
- **No animation.** The web client bobs portals and pickups, and that is the client's choice,
  not something a world can ask for.
- **No text in the world.** A sect gate cannot carry its own name. This is the most obvious
  gap for this genre, and the honest route to closing it is a `label` component — a schema
  change, conformance vectors, implementations in all three validators and a version bump
  with its migration ([CONTRIBUTING.md](../CONTRIBUTING.md), *When the protocol cannot
  express your world*).
