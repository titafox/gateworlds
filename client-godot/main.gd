extends Node2D
## The game.
##
## Knows about worlds, a player and portals. It does not know about villages, sects, herbs
## or farming -- search this file for any of them and you will not find one. That is the
## point of SPEC §1: the genre lives in `worlds/`, as data, where a contributor can add one
## without touching this file.

signal world_changed(world_id: String)
signal item_collected(entity_id: String, item: String, count: int)

const Geometry := preload("res://core/world/geometry.gd")
const LocalWorldSource := preload("res://core/world/local_world_source.gd")
const Player := preload("res://core/player/player.gd")
const WorldLoader := preload("res://core/world/world_loader.gd")
const WorldRegistry := preload("res://core/world/world_registry.gd")

const INITIAL_WORLD := "pastoral_village"

var registry = null
var runtime = null
var player: CharacterBody2D = null

## A portal the player is standing in must not fire until they have stepped out of it.
##
## Without this, arriving on a spawn that overlaps a portal bounces the player straight back,
## forever. World data can avoid that by placing spawns carefully, and ours does -- but a
## client that only works because the content is careful is a client that breaks on the first
## world a contributor sends.
var _portals_armed := false


func _ready() -> void:
	setup()


func setup(source_root := "res://worlds", initial_world := INITIAL_WORLD) -> bool:
	registry = WorldRegistry.new()
	registry.add_source(LocalWorldSource.new(source_root))
	registry.load_all()

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

	runtime = WorldLoader.build(registry.world(world_id))
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


func _on_pickup_collected(entity_id: String, item: String, count: int, once: bool) -> void:
	item_collected.emit(entity_id, item, count)
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
