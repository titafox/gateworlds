extends RefCounted
## Holds the sources, and is the only way a validated world reaches the rest of the client.
##
## `docs/REGISTRY.md`: the client validates what it fetched *even when the channel is
## trusted*. ADR-0001 §4 has the server first in line and the client second, and neither
## trusts the other. So validation happens here, on the way in, once -- not at each call
## site where somebody could forget.

const Validator := preload("res://core/protocol/validator.gd")
const ValidationContext := preload("res://core/protocol/validation_context.gd")

var _sources: Array = []
## world_id -> { "world": Dictionary, "items": Array, "source": WorldSource }
var _validated := {}
## world_id -> Report, for worlds that were offered and refused.
var _rejected := {}


func add_source(source) -> void:
	_sources.append(source)


func rejected() -> Dictionary:
	return _rejected


## Reads every source, validates what they offer, and keeps only what passes.
## Returns the ids that were accepted.
func load_all() -> Array:
	_validated.clear()
	_rejected.clear()
	for source in _sources:
		for id in source.list_ids():
			if _validated.has(id):
				# First source wins. Silently preferring a later one would make load order a
				# hidden input to which world a player ends up in.
				continue
			_ingest(source, id)
	var ids := _validated.keys()
	ids.sort()
	return ids


func _ingest(source, id: String) -> void:
	var fetched: Variant = source.fetch(id)
	if typeof(fetched) != TYPE_DICTIONARY:
		return

	var world: Dictionary = fetched["world"]
	var items_doc: Variant = fetched.get("items", null)

	var item_ids: Array = []
	if typeof(items_doc) == TYPE_DICTIONARY and typeof(items_doc.get("items", null)) == TYPE_ARRAY:
		for it in items_doc["items"]:
			if typeof(it) == TYPE_DICTIONARY and typeof(it.get("id", null)) == TYPE_STRING:
				item_ids.append(it["id"])

	var world_id: String = world.get("id", id)
	var ctx = ValidationContext.new().with_world_id(world_id).with_items(item_ids)

	var report = Validator.validate(Validator.KIND_WORLD, world, ctx)
	if not report.is_ok():
		_rejected[id] = report
		return

	if typeof(items_doc) == TYPE_DICTIONARY:
		var items_report = Validator.validate(Validator.KIND_ITEMS, items_doc, ctx)
		if not items_report.is_ok():
			_rejected[id] = items_report
			return

	_validated[world_id] = {
		"world": world,
		"items": item_ids,
		"items_doc": items_doc,
		"source": source,
	}


func has(world_id: String) -> bool:
	return _validated.has(world_id)


func ids() -> Array:
	var out := _validated.keys()
	out.sort()
	return out


## The validated world document, or an empty Dictionary when the id is unknown.
## Never returns something unvalidated, which is why the caller cannot be handed a world
## that merely happened to parse.
func world(world_id: String) -> Dictionary:
	if not _validated.has(world_id):
		return {}
	return _validated[world_id]["world"]


func items_doc(world_id: String) -> Variant:
	if not _validated.has(world_id):
		return null
	return _validated[world_id]["items_doc"]


## The spawn position for a world, falling back to "default" when the named one is absent.
## Returns null when the world is unknown.
func spawn_point(world_id: String, spawn_name: String) -> Variant:
	var w := world(world_id)
	if w.is_empty():
		return null
	var spawns: Variant = w.get("spawns", null)
	if typeof(spawns) != TYPE_DICTIONARY:
		return null
	var chosen: Variant = spawns.get(spawn_name, spawns.get("default", null))
	if typeof(chosen) != TYPE_DICTIONARY:
		return null
	return chosen.get("at", null)
