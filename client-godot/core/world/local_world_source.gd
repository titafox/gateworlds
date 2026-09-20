extends "res://core/world/world_source.gd"
## Worlds read from a directory tree, one subdirectory per package.

var root := ""


func _init(p_root: String) -> void:
	root = p_root.rstrip("/")


func list_ids() -> Array:
	var ids: Array[String] = []
	for name in DirAccess.get_directories_at(root):
		if FileAccess.file_exists("%s/%s/world.json" % [root, name]):
			ids.append(name)
	ids.sort()
	return ids


func fetch(world_id: String) -> Variant:
	var dir := "%s/%s" % [root, world_id]
	var world: Variant = _read_json("%s/world.json" % dir)
	if typeof(world) != TYPE_DICTIONARY:
		return null
	var items: Variant = _read_json("%s/items.json" % dir)
	return {
		"world": world,
		"items": items if typeof(items) == TYPE_DICTIONARY else null,
	}


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())
