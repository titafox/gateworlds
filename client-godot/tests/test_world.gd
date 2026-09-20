extends RefCounted
## World loading, geometry and travel.

const Geometry := preload("res://core/world/geometry.gd")
const LocalWorldSource := preload("res://core/world/local_world_source.gd")
const Main := preload("res://main.gd")
const WorldLoader := preload("res://core/world/world_loader.gd")
const WorldRegistry := preload("res://core/world/world_registry.gd")
const WorldRuntime := preload("res://core/world/world_runtime.gd")

const WORLDS := "res://worlds"


static func run(t, tree: SceneTree) -> void:
	_geometry(t)
	_source_and_registry(t)
	_registry_refuses_bad_worlds(t)
	_loader(t)
	_reference_worlds_link(t)
	_localisation(t)
	_travel(t, tree)


static func _geometry(t) -> void:
	t.group("geometry")
	# SPEC §6.1: `at` is the top-left origin, not the centre. A client that picks the other
	# convention lays every package out differently, and nothing anywhere reports an error.
	t.eq(Geometry.rect_for(Vector2(100, 50), Vector2.ZERO, Vector2(32, 16)),
		Rect2(100, 50, 32, 16), "rect is anchored top-left at `at`")
	t.eq(Geometry.rect_for(Vector2(100, 50), Vector2(-2, -2), Vector2(20, 20)),
		Rect2(98, 48, 20, 20), "offset shifts the rect, it does not recentre it")
	# Godot centres collision shapes on their owner, so the conversion has to exist.
	t.eq(Geometry.centre_offset(Vector2.ZERO, Vector2(32, 16)), Vector2(16, 8),
		"a centred shape sits half a size in")
	t.eq(Geometry.centre_offset(Vector2(-2, -2), Vector2(20, 20)), Vector2(8, 8),
		"offset and centring compose")
	t.eq(Geometry.coord([3, 4]), Vector2(3, 4), "coord pair")
	t.eq(Geometry.coord(null), Vector2.ZERO, "malformed coord does not crash")
	t.eq(Geometry.color("#7fe08a"), Color("#7fe08a"), "hex colour")


static func _source_and_registry(t) -> void:
	t.group("registry")
	var source := LocalWorldSource.new(WORLDS)
	var ids := source.list_ids()
	t.ok(ids.has("pastoral_village") and ids.has("xianxia_gate"),
		"the source finds both shipped worlds, found %s" % str(ids))

	var registry = WorldRegistry.new()
	registry.add_source(source)
	var accepted: Array = registry.load_all()
	t.eq(registry.rejected().size(), 0, "no shipped world is refused")
	t.ok(accepted.has("pastoral_village") and accepted.has("xianxia_gate"),
		"both worlds validate on the way in")
	t.ok(not registry.world("xianxia_gate").is_empty(), "a validated world comes back")
	t.ok(registry.world("no_such_world").is_empty(), "an unknown id yields nothing, not a crash")
	# Compared as the game consumes them. Godot's JSON parser returns 110 as a float, which
	# is exactly why the schema validator's integer check looks at the value rather than at
	# how the parser chose to spell it.
	t.eq(Geometry.coord(registry.spawn_point("xianxia_gate", "from_village")), Vector2(110, 228),
		"named spawn")
	t.eq(Geometry.coord(registry.spawn_point("xianxia_gate", "no_such_spawn")), Vector2(96, 96),
		"an unknown spawn falls back to default rather than stranding the player")
	t.eq(registry.spawn_point("no_such_world", "default"), null, "unknown world has no spawn")


class _FakeSource:
	extends "res://core/world/world_source.gd"
	var docs: Dictionary = {}
	func list_ids() -> Array:
		var k := docs.keys(); k.sort(); return k
	func fetch(world_id: String) -> Variant:
		return docs.get(world_id, null)


static func _registry_refuses_bad_worlds(t) -> void:
	t.group("registry refuses")
	# The client validates what it fetched even when the channel is trusted. docs/REGISTRY.md:
	# hashes prove the bytes are the ones the registry meant to serve; they prove nothing
	# about whether it should have served them.
	var fake := _FakeSource.new()
	fake.docs["smuggler"] = {"world": {
		"protocol_version": "0.1.0", "id": "smuggler", "display_name": {"en": "S"},
		"bounds": {"width": 64, "height": 64}, "spawns": {"default": {"at": [0, 0]}},
		"entities": [{"id": "e", "at": [0, 0], "components": [{"type": "summon_dragon"}]}],
	}, "items": null}
	fake.docs["fine"] = {"world": {
		"protocol_version": "0.1.0", "id": "fine", "display_name": {"en": "F"},
		"bounds": {"width": 64, "height": 64}, "spawns": {"default": {"at": [0, 0]}},
		"entities": [],
	}, "items": null}

	var registry = WorldRegistry.new()
	registry.add_source(fake)
	var accepted: Array = registry.load_all()
	t.eq(accepted, ["fine"], "only the valid world is offered")
	t.ok(registry.rejected().has("smuggler"), "the invalid one is recorded as refused")
	t.ok(not registry.has("smuggler"), "a refused world is not reachable at all")


static func _loader(t) -> void:
	t.group("loader")
	var registry = WorldRegistry.new()
	registry.add_source(LocalWorldSource.new(WORLDS))
	registry.load_all()

	var rt = WorldLoader.build(registry.world("xianxia_gate"))
	t.eq(rt.world_id, "xianxia_gate", "runtime knows its world")
	t.eq(rt.bounds(), Vector2(640, 480), "bounds come from the document")
	t.eq(rt.portals.size(), 1, "one portal")
	t.eq(rt.pickups.size(), 1, "one pickup")
	t.eq(rt.portals[0].target_world, "pastoral_village", "portal names its destination")
	t.eq(rt.portals[0].target_spawn, "from_xianxia", "portal names the spawn")
	t.eq(rt.pickups[0].item, "xianxia_gate:spirit_herb", "pickup names its item")
	t.eq(rt.pickups[0].entity_id, "herb_1", "pickup carries its entity id, for save state")

	var entity_nodes := 0
	for child in rt.root.get_children():
		if child.name.begins_with("Entity_"):
			entity_nodes += 1
	t.eq(entity_nodes, registry.world("xianxia_gate")["entities"].size(),
		"one node per entity, no more and no fewer")

	# The trust boundary: entities carry only nodes the whitelist produced.
	var herb: Node = rt.root.get_node_or_null("Entity_herb_1")
	t.ok(herb != null, "the herb entity exists")
	if herb != null:
		t.eq(herb.position, Vector2(420, 300), "entity sits at its `at`")
		var kinds: Array[String] = []
		for c in herb.get_children():
			kinds.append(c.name.split("_")[0])
		kinds.sort()
		t.eq(kinds, ["pickup", "sprite"], "only the declared components were built")
	rt.root.free()


static func _reference_worlds_link(t) -> void:
	t.group("worlds link")
	# A portal may name a world this client does not have -- SPEC §7.3 allows it. The two
	# shipped worlds must nonetheless reach each other, or the first version demonstrates
	# nothing.
	var registry = WorldRegistry.new()
	registry.add_source(LocalWorldSource.new(WORLDS))
	registry.load_all()

	for pair in [["pastoral_village", "xianxia_gate"], ["xianxia_gate", "pastoral_village"]]:
		var rt = WorldLoader.build(registry.world(pair[0]))
		var found := false
		for portal in rt.portals:
			if portal.target_world == pair[1]:
				found = true
				t.ok(registry.has(portal.target_world),
					"%s -> %s: the destination is present" % pair)
				t.ok(registry.spawn_point(portal.target_world, portal.target_spawn) != null,
					"%s -> %s: spawn %s exists" % [pair[0], pair[1], portal.target_spawn])
		t.ok(found, "%s has a portal to %s" % pair)
		rt.root.free()


static func _localisation(t) -> void:
	t.group("localisation")
	var rt = WorldRuntime.new()
	rt.world_id = "w"
	rt.world = {"display_name": {"zh-CN": "青霄山门", "en": "Azure Sky Gate", "ja": "青霄山門"}}
	t.eq(rt.display_name("zh-CN"), "青霄山门", "exact locale match")
	t.eq(rt.display_name("ja"), "青霄山門", "another exact match")
	t.eq(rt.display_name("zh"), "青霄山门", "primary subtag matches zh-CN")
	t.eq(rt.display_name("de"), "Azure Sky Gate", "unknown locale falls back to en")

	rt.world = {"display_name": {"ru": "Врата", "ja": "門"}}
	t.eq(rt.display_name("de"), "門",
		"with no en, the lexicographically smallest key wins -- deterministic, never empty")

	rt.world = {}
	t.eq(rt.display_name("en"), "w", "a world with no name falls back to its id")


static func _travel(t, tree: SceneTree) -> void:
	t.group("travel")
	var main := Main.new()
	tree.root.add_child(main)
	var visited: Array[String] = []
	main.world_changed.connect(func(id): visited.append(id))

	t.ok(main.setup(WORLDS, "pastoral_village"), "the game starts in the village")
	t.eq(main.runtime.world_id, "pastoral_village", "the village is loaded")
	t.eq(main.player.top_left(), Vector2(312, 232),
		"the player's top-left sits on the spawn, not their centre")

	# The acceptance criterion for this milestone: through the portal and back.
	t.ok(main.goto("xianxia_gate", "from_village"), "travel to the cultivation world")
	t.eq(main.runtime.world_id, "xianxia_gate", "the second world is loaded")
	t.eq(main.player.top_left(), Vector2(110, 228), "arrived on the named spawn")

	t.ok(main.goto("pastoral_village", "from_xianxia"), "travel back")
	t.eq(main.runtime.world_id, "pastoral_village", "back in the village")
	t.eq(main.player.top_left(), Vector2(508, 228), "arrived on the return spawn")
	t.eq(visited, ["pastoral_village", "xianxia_gate", "pastoral_village"],
		"world_changed fired once per arrival")

	# A portal is allowed to name a world this client does not have. Staying put beats
	# half-loading.
	var before = main.runtime.world_id
	t.ok(not main.goto("a_world_that_was_never_published", "default"),
		"travel to an unknown world is refused")
	t.eq(main.runtime.world_id, before, "and the player is left where they were")

	# Arriving must not re-trigger the portal that sent you.
	t.ok(not main._portals_armed, "portals are disarmed on arrival")

	main.free()
