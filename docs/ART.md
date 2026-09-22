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

This applies to references as much as to files. A style is not copyrightable and a
nine-hundred-year-old painting is not anybody's, so painting *in the manner of* a Song
handscroll is free. Copying pixels, prompts or code out of somebody's modern project is
not, and a repository with no licence has reserved every right by default.

If you generate it: in the United States a purely machine-generated image is not
copyrightable, which makes CC0 an accurate description rather than a claim. Other
jurisdictions differ, and a model's terms of service are a separate matter from copyright —
check the terms of whatever you used. Do not feed it someone else's characters or art and
contribute the result.

## The look: a Song handscroll

The worlds are painted in the register of a Northern Song ruled-line handscroll — think of
the riverside market scrolls of the twelfth century, of which 張擇端's *Along the River
During the Qingming Festival* is the one everybody knows. That painting is about nine
hundred years old and belongs to nobody; what follows is a description of how it is made,
not of anyone's modern interpretation of it.

It happens to fit this protocol unusually well:

| The painting does this | The protocol already forces it |
|---|---|
| **界画** — ruled-line architecture drawn straight on | Axis-aligned rectangles; there is no other shape |
| **No cast shadows** | A sprite is a flat fill; nothing casts anything |
| **散点透视** — no single vanishing point | The camera is the client's business, not the world's |
| Flat colour inside a drawn contour | A fill, and an outline the renderer adds |

So the constraint that started as a limitation is, for this style, the correct technique.

### The palette

绢本设色: ink and mineral pigment on silk. Muted, warm, never saturated. Pure black and
pure white do not appear — ink is a warm dark grey, and the brightest thing in the picture
is the silk itself.

| | Hex | |
|---|---|---|
| 绢底 silk ground | `#d9cba8` `#cfc09c` `#c6c29a` | The paper, and most world backgrounds |
| 墨 ink | `#3a3630` | Contours. Never `#000` |
| 赭石 ochre | `#b07a4a` `#a87f52` `#8a6a45` | Timber, earth walls, bridge decks |
| 石绿 malachite | `#7d9b76` `#6f9b5e` `#4f6b52` | Foliage, jade, spirit herbs |
| 花青 indigo | `#7d9bad` `#6d8396` `#5b7186` | Water, distant hills, cloth |
| 藤黄 gamboge | `#c9a24a` `#c2a465` | Thatch, bronze, paper lanterns |
| 朱砂 cinnabar | `#b2452f` | Awnings, seals. **Sparingly** — it is the loudest thing available |
| 白垩 chalk | `#cfc7b4` `#e4dcc6` | Stone, plaster, worn steps |

### The prompt

Generated art arrives with lighting, perspective and a centred subject baked in. All three
are supplied by the renderer or forbidden by the style, so the negatives are doing most of
the work here.

```
A seamless tileable texture of {MATERIAL}, painted in the manner of a Northern Song
ruled-line handscroll: ink and mineral pigment on aged silk.

Fine warm dark-grey ink contour lines, dry-brush texture, flat washes of colour inside
the contours. Muted and desaturated. Warm ivory silk showing through. Visible paper grain.

Completely flat even lighting. No cast shadows, no highlights, no sheen, no gradient
across the tile. Straight down, orthographic, no perspective, no horizon, no vanishing
point, no ground line.

Dominant colour {HEX}. Hold the whole tile within one narrow value range.
Square, edge-to-edge, seamless on all four sides.

No text, no calligraphy, no seals, no signature, no characters, no people, no animals,
no logos, no borders, no frame, no vignette, no drop shadow, no 3D render, no isometric
view, no glossy surface, no single object centred in the frame.
```

Fill `{MATERIAL}` and `{HEX}` from the tables below. The hexes are what those entities use
today, so a texture built around them drops in without the world looking re-lit.

### 虹桥坊市 `bridge_market` — a market on both banks

| Entity | Material | Hex |
|---|---|---|
| `river` `water_west` `water_east` | slow river water, fine ink ripple lines, no reflection | `#8fa8ba` |
| `bridge_deck` | worn timber planking laid crosswise | `#a87f52` |
| `rail_west` `rail_east` `barge` | dark oiled timber, visible grain | `#8a6a45` |
| `stall_*` | plastered market stall wall, bamboo frame | `#b58f5c` |
| `awning_nw` `awning_sw` | coarse woven cloth awning, faded | `#b2452f` / `#5b7186` |

### 月麓村 `yuelu_village` — a village at the foot of the mountain

| Entity | Material | Hex |
|---|---|---|
| `hut_*` | rammed earth wall, straw fibres in the mud, cracked | `#a87f52` |
| `thatch_*` | dry rice straw thatch, bundled, weathered | `#c2a465` |
| `well` | wet dark stone rim, moss in the joints | `#6d8396` |
| `cart_track` | packed dirt track, faint wheel ruts | `#bda98a` |
| `wall_*` | old mud-brick boundary wall | `#8a7352` |

### 登云道 `cloud_stair` — seven hundred steps in mist

| Entity | Material | Hex |
|---|---|---|
| `cliff_*` `wall_*` | wet granite, vertical fracture lines, 斧劈皴 axe-cut strokes | `#7d8a8c` |
| `step_0` … `step_6` | worn stone stair tread, hollowed in the middle | `#cfc7b4` |
| `pine` `pine_2` | dense pine canopy seen from above, ink dabs | `#4f6b52` |

### 岐峰门 `qifeng_gate` — the gate of a minor sect

| Entity | Material | Hex |
|---|---|---|
| `pillar_*` | carved granite column, faint cloud scroll relief | `#cfc7b4` |
| `lintel` `stone_lion_*` | chiselled dark stone | `#8c8779` |
| `plaque` | polished green jade, cloudy veining | `#6f9b84` |
| `bell` | patinated bronze, verdigris in the recesses | `#a8823f` |

### 灵田 `spirit_field` — terraced fields

| Entity | Material | Hex |
|---|---|---|
| `terrace_*` | turned dark loam with young shoots in rows | `#8ba36f` |
| `channel` | shallow still irrigation water | `#7d9bad` |
| `stone_edge_*` | dry-stacked field stones | `#a09a83` |
| `shed` | weathered timber planks | `#8a7352` |

### Portals

`#8a76a6` is the one colour that means the same thing in every world. Texture all of them
the same way or none of them, or it stops meaning anything.

| Entity | Material | Hex |
|---|---|---|
| any portal | pale violet talisman paper, seal-script strokes dissolving at the edges | `#8a76a6` |

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
