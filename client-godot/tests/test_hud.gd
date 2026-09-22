extends RefCounted
## The HUD's derived colours.
##
## The panel and its text are computed from whatever background a world declares, and a
## community world can declare anything. These properties are the difference between an
## interface that works on the two worlds shipped today and one that works on the third
## world somebody contributes.

const Hud := preload("res://ui/hud.gd")
const HudTheme := preload("res://ui/hud_theme.gd")
const Inventory := preload("res://core/inventory/inventory.gd")
const Main := preload("res://main.gd")

const WORLDS := "res://worlds"


static func run(t, tree: SceneTree) -> void:
	_separation(t)
	_text_contrast(t)
	_rows(t, tree)


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


static func _separation(t) -> void:
	t.group("hud separation")
	# Every colour a world might declare, including the two extremes where the naive rule --
	# "darken it" -- has nowhere to go.
	var backgrounds := [
		Color("#000000"), Color("#0a0a0a"), Color("#1b2430"), Color("#2e4a2e"),
		Color("#808080"), Color("#c9c9c9"), Color("#ffffff"), Color("#7fe08a"),
		Color("#9b7fe0"), Color("#e08a3c"),
	]
	for bg in backgrounds:
		var panel: Color = HudTheme.panel_for(bg)
		var delta: float = absf(_lum(panel) - _lum(bg))
		t.ok(delta >= HudTheme.MIN_SEPARATION,
			"panel separates from %s (delta %.3f, need %.3f)"
			% [bg.to_html(false), delta, HudTheme.MIN_SEPARATION])

	# The specific case the rule exists for: pure black cannot be darkened, so the panel has
	# to go the other way.
	t.ok(_lum(HudTheme.panel_for(Color("#000000"))) > 0.0,
		"a black world gets a panel lighter than itself, not an invisible one")
	t.ok(_lum(HudTheme.panel_for(Color("#ffffff"))) < 1.0,
		"a white world gets a panel darker than itself")


static func _text_contrast(t) -> void:
	t.group("hud contrast")
	# Text is picked from the panel it sits on, not assumed. Without this a pale world gives
	# off-white text on an off-white panel: present, legible to nobody.
	for bg in [Color("#000000"), Color("#1b2430"), Color("#2e4a2e"),
			Color("#c9c9c9"), Color("#ffffff"), Color("#7fe08a")]:
		var panel: Color = HudTheme.panel_for(bg)
		var text: Color = HudTheme.text_on(panel)
		var delta: float = absf(_lum(text) - _lum(panel))
		t.ok(delta > 0.35,
			"text is readable on the panel for %s (delta %.2f)" % [bg.to_html(false), delta])

	t.eq(HudTheme.text_on(Color("#ffffff")), HudTheme.INK, "dark text on a light panel")
	t.eq(HudTheme.text_on(Color("#000000")), HudTheme.PAPER, "light text on a dark panel")


static func _rows(t, tree: SceneTree) -> void:
	t.group("hud rows")
	var main := Main.new()
	tree.root.add_child(main)
	main.setup(WORLDS, "pastoral_village", "user://test_hud.json")
	main.locale = "zh-CN"

	t.eq(main.inventory_rows(), [], "an empty inventory has no rows")

	main.inventory.add("xianxia_gate:spirit_herb", 1)
	main._refresh_hud()
	var rows: Array = main.inventory_rows()
	t.eq(rows.size(), 1, "one stack, one row")
	t.eq(rows[0]["name"], "灵草", "the item is named in the player's language")
	t.eq(rows[0]["origin"], "青霄山门",
		"and says which world it came from -- the interesting fact about a travelling thing")
	t.eq(rows[0]["count"], 1, "with its count")
	t.eq(rows[0]["icon"], Color("#6f9b5e"),
		"the icon is the item's own colour, the same rectangle the world draws")

	# Split stacks are separate in the save, so they are separate on screen. Collapsing them
	# in the display would hide a distinction the rest of the client is careful to keep.
	main.inventory.from_save([
		{"item": "pastoral_village:carrot", "count": 2, "props": {"freshness": 1.0}},
		{"item": "pastoral_village:carrot", "count": 5, "props": {"freshness": 0.3}},
	])
	t.eq(main.inventory_rows().size(), 2, "two stacks of one item show as two rows")

	# An item whose world is no longer installed still has to render as something.
	main.inventory.from_save([{"item": "gone:relic", "count": 1}])
	var orphan: Array = main.inventory_rows()
	t.eq(orphan[0]["name"], "gone:relic", "an unresolvable item falls back to its id")
	t.eq(orphan[0]["origin"], "gone", "and its origin to the namespace, which is still true")

	t.ok(not main.hud.is_inventory_open(), "the panel starts closed")
	main.hud.toggle_inventory()
	t.ok(main.hud.is_inventory_open(), "and I opens it")

	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_hud.json"))
