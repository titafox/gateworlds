extends RefCounted
## The HUD's material.
##
## The worlds are drawn as flat, unshaded, axis-aligned rectangles, because at protocol
## 0.1.0 that is the entire visual vocabulary a world is allowed (SPEC §7.1). That is not a
## placeholder look to be papered over -- it is what the protocol currently says a world can
## be. So the HUD is built from the same material: flat rects, no radius, no shadow, no
## gradient, no decorative borders. Separation comes from value, never from a line.
##
## The panel takes its colour from the world the player is standing in. In a universe of
## worlds, the interface saying where you are is worth more than the interface having a
## house style.

## Text on a dark panel: the same off-white the player's own square is drawn in.
const PAPER := Color("#e8e4d9")
## Text on a light panel.
const INK := Color("#14171c")
## Secondary text -- provenance, key hints. Never used for anything a player must read.
const DIM_ON_DARK := Color("#7f8894")
const DIM_ON_LIGHT := Color("#5a6069")
## The portal purple, already the game's colour for "a transition happened". Reused rather
## than inventing an accent: the HUD's transitions are the same kind of event.
const SIGNAL := Color("#8a76a6")

const PAD := 8.0
const ROW_HEIGHT := 28.0
const ICON := 12.0
const PANEL_WIDTH := 148.0

const SIZE_WORLD := 13
const SIZE_ITEM := 12
const SIZE_META := 10


## How far a panel must sit from its world in luminance before it reads as a separate
## surface rather than a slightly different patch of ground.
const MIN_SEPARATION := 0.055

## The panel colour for a world: its own background, pushed until it separates.
##
## Darkening alone is not enough. A world that is already nearly black -- and the cultivation
## world is -- has nowhere darker to go, so the panel lands within a few percent of the
## background and the interface dissolves into it. When there is no room below, the panel
## goes up instead.
##
## A community world can be any colour, so neither the panel nor its text is assumed: both
## are derived, and the result is checked rather than hoped for.
static func panel_for(world_background: Color) -> Color:
	var base := world_background
	var down := base.darkened(0.55)
	if absf(_luminance(base) - _luminance(down)) >= MIN_SEPARATION:
		return down
	return base.lightened(0.30)


static func text_on(panel: Color) -> Color:
	return INK if _luminance(panel) > 0.5 else PAPER


static func dim_on(panel: Color) -> Color:
	return DIM_ON_LIGHT if _luminance(panel) > 0.5 else DIM_ON_DARK


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## One family, at three sizes; size alone carries the hierarchy.
##
## A system font with fallback, because the project ships in Chinese, English, Russian and
## Japanese and Godot's bundled font has no CJK coverage at all -- 灵草 would render as empty
## boxes. A HUD that cannot spell the item in the first playable version is not a HUD.
static func font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Sans-Serif"])
	f.allow_system_fallback = true
	return f
