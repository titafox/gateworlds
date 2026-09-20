extends Node2D
## The game.
##
## Knows about worlds, a player and portals. It does not know about villages, sects, herbs
## or farming -- search this file for any of them and you will not find one. That is the
## point of SPEC §1: the genre lives in `worlds/`, as data, where a contributor can add one
## without touching this file.

signal world_changed(world_id: String)
signal item_collected(entity_id: String, item: String, count: int)
signal notice(text: String)

const Geometry := preload("res://core/world/geometry.gd")
const Inventory := preload("res://core/inventory/inventory.gd")
const ItemCatalog := preload("res://core/inventory/item_catalog.gd")
const LocalWorldSource := preload("res://core/world/local_world_source.gd")
const Player := preload("res://core/player/player.gd")
const SaveManager := preload("res://core/save/save_manager.gd")
const WorldLoader := preload("res://core/world/world_loader.gd")
const WorldRegistry := preload("res://core/world/world_registry.gd")

const INITIAL_WORLD := "pastoral_village"

var registry = null
var runtime = null
var player: CharacterBody2D = null
var catalog = null
var inventory = null
var saves = null

## world_id -> { "consumed_pickups": Array[String] }. SPEC §10.
var world_state: Dictionary = {}
var _created_at := ""

## A portal the player is standing in must not fire until they have stepped out of it.
##
## Without this, arriving on a spawn that overlaps a portal bounces the player straight back,
## forever. World data can avoid that by placing spawns carefully, and ours does -- but a
## client that only works because the content is careful is a client that breaks on the first
## world a contributor sends.
var _portals_armed := false


func _ready() -> void:
	setup()


func setup(source_root := "res://worlds", initial_world := INITIAL_WORLD,
		save_path := SaveManager.DEFAULT_PATH) -> bool:
	registry = WorldRegistry.new()
	registry.add_source(LocalWorldSource.new(source_root))
	registry.load_all()

	catalog = ItemCatalog.new()
	catalog.load_from_registry(registry)
	inventory = Inventory.new()
	saves = SaveManager.new(save_path)
	_created_at = SaveManager.now_utc()

	for id in registry.rejected():
		push_error("world %s was refused and will not be offered: %s" % [id, registry.rejected()[id].findings])

	player = Player.create()
	add_child(player)

	return goto(initial_world, "default")


## Swaps the current world for another and puts the player on the named spawn.
##
## Returns false rather than half-loading when the destination is unknown: a portal may name
## a world this client does not have (SPEC §7.3 allows exactly that), and the right answer is
## to stay where you are.
func goto(world_id: String, spawn_name: String) -> bool:
	if registry == null or not registry.has(world_id):
		return false
	var at: Variant = registry.spawn_point(world_id, spawn_name)
	if at == null:
		return false

	if runtime != null and is_instance_valid(runtime.root):
		remove_child(runtime.root)
		runtime.root.queue_free()

	runtime = WorldLoader.build(registry.world(world_id), consumed_in(world_id))
	add_child(runtime.root)
	move_child(runtime.root, 0)

	for portal in runtime.portals:
		portal.entered.connect(_on_portal_entered)
	for pickup in runtime.pickups:
		pickup.collected.connect(_on_pickup_collected)

	player.place_top_left_at(Geometry.coord(at))
	_portals_armed = false
	world_changed.emit(world_id)
	return true


func _physics_process(_delta: float) -> void:
	if _portals_armed or runtime == null or player == null:
		return
	for portal in runtime.portals:
		if is_instance_valid(portal) and player in portal.get_overlapping_bodies():
			return
	_portals_armed = true


func _on_portal_entered(target_world: String, target_spawn: String) -> void:
	if not _portals_armed:
		return
	# Disarm immediately, defer the swap.
	#
	# This runs inside a physics callback, and Godot forbids removing a collision object
	# from there -- it reports "undesired behavior" and carries on, which is the worst kind
	# of bug: the game looks like it worked. Two portals overlapping would also both fire
	# before either swap happened, so the flag has to drop here rather than inside goto().
	_portals_armed = false
	goto.call_deferred(target_world, target_spawn)


func consumed_in(world_id: String) -> Array:
	var entry: Variant = world_state.get(world_id, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return []
	var list: Variant = entry.get("consumed_pickups", [])
	return list if typeof(list) == TYPE_ARRAY else []


func _record_consumed(world_id: String, entity_id: String) -> void:
	if not world_state.has(world_id):
		world_state[world_id] = {"consumed_pickups": []}
	var list: Array = world_state[world_id]["consumed_pickups"]
	if not list.has(entity_id):
		list.append(entity_id)


# ------------------------------------------------------------------------------ saving

## Everything that has to survive being closed. SPEC §10.
func capture_state() -> Dictionary:
	var at: Vector2 = player.top_left()
	return {
		"created_at": _created_at,
		"player": {
			"current_world": runtime.world_id,
			"at": [int(roundf(at.x)), int(roundf(at.y))],
		},
		"inventory": {"stacks": inventory.to_save()},
		# SPEC §8.3: the definitions travel with the save, so it stays readable even if the
		# world that defined them is gone.
		"item_defs": catalog.snapshot_for(inventory.item_ids()),
		"world_state": world_state.duplicate(true),
	}


func save_game() -> bool:
	var ok: bool = saves.write(capture_state())
	notice.emit("saved" if ok else "save failed: %s" % saves.last_error)
	return ok


func load_game() -> bool:
	var doc: Variant = saves.read()
	if doc == null:
		notice.emit("load failed: %s" % saves.last_error)
		return false
	return apply_state(doc)


## Restores a validated save.
##
## When the saved world is no longer available -- unpublished, renamed, withdrawn -- the
## player is put back in the starting world rather than refused. Their inventory is intact
## either way: losing what someone was carrying because a world went away is exactly the
## failure *Protection of existing work* forbids.
func apply_state(doc: Dictionary) -> bool:
	_created_at = str(doc.get("created_at", SaveManager.now_utc()))
	catalog.load_snapshot(doc.get("item_defs", {}))
	inventory.from_save(doc.get("inventory", {}).get("stacks", []))

	var state: Variant = doc.get("world_state", {})
	world_state = state.duplicate(true) if typeof(state) == TYPE_DICTIONARY else {}

	var saved_player: Dictionary = doc.get("player", {})
	var world_id := str(saved_player.get("current_world", ""))
	var at: Vector2 = Geometry.coord(saved_player.get("at", null))

	if not registry.has(world_id):
		notice.emit("world %s is no longer available; returning to %s" % [world_id, INITIAL_WORLD])
		var fell_back := goto(INITIAL_WORLD, "default")
		notice.emit("loaded" if fell_back else "load failed: no world to return to")
		return fell_back

	if not goto(world_id, "default"):
		return false
	player.place_top_left_at(at)
	notice.emit("loaded")
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F5:
			save_game()
		KEY_F9:
			load_game()


func _on_pickup_collected(entity_id: String, item: String, count: int, once: bool) -> void:
	inventory.add(item, count, catalog.stack_limit(item))
	item_collected.emit(entity_id, item, count)
	notice.emit("picked up %s x%d" % [catalog.display_name(item), count])
	if once and runtime != null:
		_record_consumed(runtime.world_id, entity_id)
	if not once:
		return
	# Same physics-callback rule as portals: queue_free() is already deferred, but the node
	# must leave the tree deferred too, or the collision object is removed mid-query.
	for pickup in runtime.pickups:
		if is_instance_valid(pickup) and pickup.entity_id == entity_id:
			var holder: Node = pickup.get_parent()
			if holder != null:
				holder.get_parent().remove_child.call_deferred(holder)
				holder.queue_free()
