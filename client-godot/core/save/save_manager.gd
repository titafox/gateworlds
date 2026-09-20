extends RefCounted
## Reading and writing the save.
##
## A save is external content. It can be hand-edited, copied from another machine, or
## written by a different build -- so it is validated on the way in exactly like a world
## package is. The client does not get to trust a file merely because it wrote one there
## once.

const Migrations := preload("res://core/save/migrations.gd")
const ProtocolVersion := preload("res://core/protocol/protocol_version.gd")
const ValidationContext := preload("res://core/protocol/validation_context.gd")
const Validator := preload("res://core/protocol/validator.gd")

const DEFAULT_PATH := "user://save_0.json"

var path := DEFAULT_PATH
## Findings from the last failed read, for showing the player why their save was refused.
var last_error := ""


func _init(p_path := DEFAULT_PATH) -> void:
	path = p_path


func exists() -> bool:
	return FileAccess.file_exists(path)


static func now_utc() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"


## Writes atomically: a temporary file in the same directory, flushed, then renamed over the
## target.
##
## SPEC §10 requires this, and the reason is worth stating plainly: a partially written save
## is worse than an old one. A crash between "truncate" and "finish writing" on a
## write-in-place would destroy hours of play and leave a file that still looks like a save.
func write(state: Dictionary) -> bool:
	state = state.duplicate(true)
	state["save_version"] = ProtocolVersion.VERSION_STRING
	if not state.has("created_at"):
		state["created_at"] = now_utc()
	state["updated_at"] = now_utc()

	# Validate before writing, not only after reading. A build that can produce a save it
	# would itself refuse has a bug, and the time to find out is now.
	var report = Validator.validate(Validator.KIND_SAVE, state, ValidationContext.new())
	if not report.is_ok():
		last_error = "refusing to write an invalid save: %s" % _describe(report)
		push_error(last_error)
		return false

	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_error = "cannot open %s: %s" % [tmp, error_string(FileAccess.get_open_error())]
		return false
	f.store_string(JSON.stringify(state, "  ", false))
	f.flush()
	f.close()

	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path)
	)
	if err != OK:
		last_error = "cannot replace %s: %s" % [path, error_string(err)]
		return false

	last_error = ""
	return true


## Returns the validated save, or null. `last_error` says why.
func read() -> Variant:
	last_error = ""
	if not exists():
		last_error = "no save at %s" % path
		return null

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		last_error = "cannot open %s" % path
		return null
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "%s is not a JSON object" % path
		return null

	var migrated := Migrations.apply(parsed)
	if not migrated["ok"]:
		last_error = migrated["error"]
		return null

	var doc: Dictionary = migrated["doc"]
	var report = Validator.validate(Validator.KIND_SAVE, doc, ValidationContext.new())
	if not report.is_ok():
		last_error = "save did not validate: %s" % _describe(report)
		return null

	return doc


static func _describe(report) -> String:
	var parts: Array[String] = []
	for finding in report.findings:
		parts.append(str(finding))
	return "; ".join(parts)
