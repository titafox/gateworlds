extends RefCounted
## Turns a validated world document into a scene tree.
##
## The loader never reads a path, a class name or a script reference out of the document.
## The only thing it takes from data is a component *type name*, which it looks up in a
## fixed table. That is the whole of the trust boundary: a world says what it wants, the
## engine decides what that means.

const ComponentRegistry := preload("res://core/components/component_registry.gd")
const CompPickup := preload("res://core/components/comp_pickup.gd")
const CompPortal := preload("res://core/components/comp_portal.gd")
const CompSprite := preload("res://core/components/comp_sprite.gd")
const Geometry := preload("res://core/world/geometry.gd")
const WorldRuntime := preload("res://core/world/world_runtime.gd")


## `world` must already have passed validation -- see WorldRegistry. Passing an unvalidated
## document here is a programming error, not a user error, so the loader does not re-check.
##
## `consumed` lists entity ids whose `once` pickup has already been taken in this save. Those
## entities are not built at all, which matches what happens at runtime when one is collected:
## the whole entity goes, not just its pickup. A herb that reappeared on reload -- or left its
## sprite behind with nothing to collect -- would both be wrong in the same way.
static func build(world: Dictionary, consumed: Array = []) -> WorldRuntime:
	var rt := WorldRuntime.new()
	rt.world = world
	rt.world_id = str(world.get("id", ""))

	var root := Node2D.new()
	root.name = "World_%s" % rt.world_id
	rt.root = root

	var bg := _background(world, rt.bounds())
	if bg != null:
		root.add_child(bg)

	var entities: Variant = world.get("entities", null)
	if typeof(entities) != TYPE_ARRAY:
		return rt

	for entity in entities:
		if typeof(entity) != TYPE_DICTIONARY:
			continue
		var entity_id := str(entity.get("id", ""))
		if consumed.has(entity_id):
			continue
		var holder := Node2D.new()
		holder.name = "Entity_%s" % entity_id
		holder.position = Geometry.coord(entity.get("at", null))
		root.add_child(holder)

		for component in entity.get("components", []):
			if typeof(component) != TYPE_DICTIONARY:
				continue
			var type_name := str(component.get("type", ""))
			var node := ComponentRegistry.build(type_name, component)
			if node == null:
				continue
			node.name = "%s_%s" % [type_name, entity_id]
			holder.add_child(node)

			if node is CompPortal:
				rt.portals.append(node)
			elif node is CompPickup:
				node.entity_id = entity_id
				rt.pickups.append(node)

	return rt


static func _background(world: Dictionary, size: Vector2) -> Node2D:
	var raw: Variant = world.get("background", null)
	if typeof(raw) != TYPE_STRING:
		return null
	# Built through the same component that draws every other rectangle. A background with
	# its own drawing path would be a second place for "how a world looks" to live.
	var node := CompSprite.build({
		"size": [int(size.x), int(size.y)],
		"color": raw,
		"z": -1000,
	})
	node.name = "Background"
	return node
