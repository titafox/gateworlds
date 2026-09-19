extends SceneTree

func _initialize() -> void:
	print("godot headless script: OK")
	print("  version: %s" % Engine.get_version_info().string)
	var f := FileAccess.open("res://protocol/world-v0.1.schema.json", FileAccess.READ)
	if f == null:
		print("  schema via symlink: FAILED (%s)" % FileAccess.get_open_error())
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	print("  schema via symlink: OK, $id = %s" % parsed.get("$id", "?"))
	var re := RegEx.create_from_string("^[a-z0-9]([a-z0-9_]*[a-z0-9])?$")
	print("  regex engine: %s" % ("OK" if re != null and re.search("xianxia_gate") != null else "FAILED"))
	quit(0)
