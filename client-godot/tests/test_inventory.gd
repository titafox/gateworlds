extends RefCounted
## Inventory, the item catalog, saving, and the milestone's headline claim.

const Inventory := preload("res://core/inventory/inventory.gd")
const ItemCatalog := preload("res://core/inventory/item_catalog.gd")
const Main := preload("res://main.gd")
const Migrations := preload("res://core/save/migrations.gd")
const SaveManager := preload("res://core/save/save_manager.gd")

const WORLDS := "res://worlds"
const HERB := "xianxia_gate:spirit_herb"
const CARROT := "pastoral_village:carrot"


static func run(t, tree: SceneTree) -> void:
	_inventory(t)
	_catalog(t)
	_save_roundtrip(t)
	_save_refuses_bad_input(t)
	_migrations(t)
	_the_herb_comes_home(t, tree)
	_a_missing_world_does_not_cost_the_player_anything(t, tree)


static func _inventory(t) -> void:
	t.group("inventory")
	var inv = Inventory.new()
	t.ok(inv.is_empty(), "starts empty")

	inv.add(HERB, 1)
	t.eq(inv.total(HERB), 1, "one herb")
	inv.add(HERB, 2)
	t.eq(inv.stacks.size(), 1, "same item and props fills the existing stack")
	t.eq(inv.total(HERB), 3, "three herbs")

	inv.add(CARROT, 5, 3)
	t.eq(inv.total(CARROT), 5, "five carrots")
	t.eq(inv.stacks.size(), 3, "a stack limit of 3 opens a second and third stack")

	# Props are opaque, so two stacks that differ in them must not be merged: this code has
	# no way to know what it would be throwing away.
	var fresh = Inventory.new()
	fresh.add(CARROT, 1, 99, {"freshness": 1.0})
	fresh.add(CARROT, 1, 99, {"freshness": 0.3})
	t.eq(fresh.stacks.size(), 2, "stacks with different props stay apart")

	# SPEC §10: a save may hold two stacks of one item, and loading must not merge them.
	var loaded = Inventory.new()
	loaded.from_save([
		{"item": CARROT, "count": 2, "props": {"freshness": 1.0}},
		{"item": CARROT, "count": 5, "props": {"freshness": 0.3}},
	])
	t.eq(loaded.stacks.size(), 2, "split stacks survive loading")
	t.eq(loaded.total(CARROT), 7, "and hold what they held")
	t.eq(loaded.stacks[0]["count"], 2, "slot order is preserved")
	t.eq(loaded.item_ids(), [CARROT], "distinct ids for the definition snapshot")


static func _catalog(t) -> void:
	t.group("catalog")
	var cat = ItemCatalog.new()
	cat.load_snapshot({HERB: {
		"id": HERB, "display_name": {"en": "Old Name"}, "icon": {"color": "#111111"}}})
	t.eq(cat.display_name(HERB), "Old Name", "the snapshot resolves when nothing else does")

	# The live catalog wins, so a world author can fix a typo and have it take effect on
	# saves written before the fix.
	cat._live[HERB] = {"id": HERB, "display_name": {"en": "Spirit Herb"}, "icon": {"color": "#7fe08a"}}
	t.eq(cat.display_name(HERB), "Spirit Herb", "the live definition takes precedence")

	t.ok(not cat.is_known("nobody:knows_this"), "an unknown item is unknown")
	t.eq(cat.display_name("nobody:knows_this"), "nobody:knows_this",
		"an unresolvable item still renders as something rather than blank")

	# SPEC §8.2: a stack must never be lost because its world is unavailable. The snapshot
	# therefore carries a stand-in rather than omitting the entry.
	var snap: Dictionary = cat.snapshot_for([HERB, "nobody:knows_this"])
	t.eq(snap.size(), 2, "the snapshot covers every held item, known or not")
	t.eq(snap["nobody:knows_this"]["id"], "nobody:knows_this", "with a placeholder definition")

	t.eq(cat.props(HERB), {}, "props default to empty, and are never interpreted")


static func _save_roundtrip(t) -> void:
	t.group("save")
	var path := "user://test_roundtrip.json"
	var saves = SaveManager.new(path)
	var state := {
		"player": {"current_world": "pastoral_village", "at": [128, 200]},
		"inventory": {"stacks": [{"item": HERB, "count": 1}]},
		"item_defs": {HERB: {
			"id": HERB, "display_name": {"zh-CN": "灵草", "en": "Spirit Herb"},
			"icon": {"color": "#7fe08a"}, "props": {"spirit_qi": 3}}},
		"world_state": {"xianxia_gate": {"consumed_pickups": ["herb_1"]}},
	}
	t.ok(saves.write(state), "a well-formed save is written: %s" % saves.last_error)

	var back: Variant = saves.read()
	t.ok(back != null, "and read back: %s" % saves.last_error)
	if back != null:
		t.eq(back["save_version"], "0.1.0", "the writer stamps the version")
		t.ok(back.has("created_at") and back.has("updated_at"), "and both timestamps")
		t.eq(back["inventory"]["stacks"][0]["item"], HERB, "the stack survives")
		t.eq(back["item_defs"][HERB]["props"]["spirit_qi"], 3,
			"opaque item props survive a round trip untouched")
		t.eq(back["world_state"]["xianxia_gate"]["consumed_pickups"], ["herb_1"],
			"world state survives")

	t.ok(not FileAccess.file_exists(path + ".tmp"),
		"the temporary file is gone -- the write was a rename, not a truncate")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _save_refuses_bad_input(t) -> void:
	t.group("save refuses")
	var path := "user://test_refuse.json"
	var saves = SaveManager.new(path)

	# A build that can write a save it would itself refuse has a bug, and the time to find
	# out is at the write.
	t.ok(not saves.write({"player": {"current_world": "w"}, "inventory": {"stacks": []},
		"item_defs": {}}), "a save missing a required field is refused")
	t.ok(not FileAccess.file_exists(path), "and nothing is written")

	# A save is external content: hand-edited, copied between machines, written by another
	# build. It is validated on the way in like anything else.
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"save_version":"0.2.0","created_at":"2026-01-01T00:00:00Z",'
		+ '"updated_at":"2026-01-01T00:00:00Z","player":{"current_world":"w","at":[0,0]},'
		+ '"inventory":{"stacks":[]},"item_defs":{}}')
	f.close()
	t.eq(saves.read(), null, "a save from a newer protocol is refused, not guessed at")
	t.ok(saves.last_error.contains("0.2.0"), "and the message names the version")

	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	t.eq(saves.read(), null, "a corrupt save is refused without crashing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _migrations(t) -> void:
	t.group("migrations")
	var same := Migrations.apply({"save_version": "0.1.0"})
	t.ok(same["ok"], "the current version needs no migration")

	var old := Migrations.apply({"save_version": "0.0.1"})
	t.ok(not old["ok"], "an unmigratable version is refused")
	t.ok(old["error"].contains("no migration"), "and says so plainly")

	var missing := Migrations.apply({})
	t.ok(not missing["ok"], "a save with no version is refused")


## The milestone. Not a metaphor for it -- this is the claim, executed.
static func _the_herb_comes_home(t, tree: SceneTree) -> void:
	t.group("the herb comes home")
	var path := "user://test_herb.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	var main := Main.new()
	tree.root.add_child(main)
	main.setup(WORLDS, "pastoral_village", path)

	t.ok(main.goto("xianxia_gate", "from_village"), "walk into the cultivation world")
	# The same call the pickup component makes when the player touches it.
	main._on_pickup_collected("herb_1", HERB, 1, true)
	t.eq(main.inventory.total(HERB), 1, "the herb is picked up")
	t.eq(main.consumed_in("xianxia_gate"), ["herb_1"], "and recorded as taken")

	t.ok(main.goto("pastoral_village", "from_xianxia"), "walk back to the village")
	t.eq(main.inventory.total(HERB), 1,
		"THE HERB IS STILL THERE -- inventory belongs to the player, not to a world")
	t.eq(main.catalog.display_name(HERB, "zh-CN"), "灵草",
		"and the village can name an item it has never heard of")

	t.ok(main.save_game(), "save")
	main.free()

	# A different game object entirely: nothing carried over in memory.
	var reopened := Main.new()
	tree.root.add_child(reopened)
	reopened.setup(WORLDS, "pastoral_village", path)
	t.eq(reopened.inventory.total(HERB), 0, "the new session starts empty")

	t.ok(reopened.load_game(), "load: %s" % reopened.saves.last_error)
	t.eq(reopened.inventory.total(HERB), 1, "THE HERB SURVIVED BEING CLOSED AND REOPENED")
	t.eq(reopened.runtime.world_id, "pastoral_village", "and the player is where they left off")
	t.eq(reopened.consumed_in("xianxia_gate"), ["herb_1"], "the herb is still recorded as taken")

	# And it does not grow back.
	t.ok(reopened.goto("xianxia_gate", "from_village"), "return to where the herb was")
	t.eq(reopened.runtime.pickups.size(), 0, "the herb has not respawned")
	t.ok(reopened.runtime.root.get_node_or_null("Entity_herb_1") == null,
		"its entity is not rebuilt at all, sprite included")

	reopened.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _a_missing_world_does_not_cost_the_player_anything(t, tree: SceneTree) -> void:
	t.group("missing world")
	var path := "user://test_missing.json"
	var main := Main.new()
	tree.root.add_child(main)
	main.setup(WORLDS, "pastoral_village", path)

	# A save written when a world existed, loaded after it was withdrawn.
	var doc := {
		"save_version": "0.1.0",
		"created_at": "2026-01-01T00:00:00Z", "updated_at": "2026-01-01T00:00:00Z",
		"player": {"current_world": "a_world_that_was_withdrawn", "at": [10, 10]},
		"inventory": {"stacks": [{"item": "a_world_that_was_withdrawn:relic", "count": 2}]},
		"item_defs": {"a_world_that_was_withdrawn:relic": {
			"id": "a_world_that_was_withdrawn:relic",
			"display_name": {"en": "Relic"}, "icon": {"color": "#cccccc"}}},
		"world_state": {},
	}
	t.ok(main.apply_state(doc), "the save still loads")
	t.eq(main.runtime.world_id, "pastoral_village", "the player is returned to the start")
	t.eq(main.inventory.total("a_world_that_was_withdrawn:relic"), 2,
		"AND KEEPS THEIR ITEMS -- losing them because a world went away is the failure "
		+ "Protection of existing work forbids")
	t.eq(main.catalog.display_name("a_world_that_was_withdrawn:relic"), "Relic",
		"the embedded snapshot still names an item whose world is gone")

	main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
