extends RefCounted
## The conformance vector runner, per `protocol/conformance/README.md`.
##
## Counterpart to `server/crates/gateworlds-protocol/src/conformance.rs`. Both run the same
## directory. Two independent implementations agreeing on it is the evidence ADR-0001 rests
## on; one implementation is just a habit.

const Outcome := preload("res://core/protocol/vector_outcome.gd")
const ValidationContext := preload("res://core/protocol/validation_context.gd")
const Validator := preload("res://core/protocol/validator.gd")

static func run_dir(dir_path: String) -> Array:
	var files: Array[String] = []
	for sub in ["valid", "invalid"]:
		var d := "%s/%s" % [dir_path, sub]
		var names := DirAccess.get_files_at(d)
		if names.is_empty():
			push_error("no vectors under %s" % d)
		var batch: Array[String] = []
		for n in names:
			if n.ends_with(".json"):
				batch.append("%s/%s" % [d, n])
		batch.sort()
		files.append_array(batch)

	var out: Array = []
	for f in files:
		out.append(_run_one(f))
	return out


static func _run_one(path: String):
	var o := Outcome.new()
	o.name = path.get_file()

	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		o.failure = "unreadable"
		return o
	var vector: Variant = JSON.parse_string(f.get_as_text())
	if typeof(vector) != TYPE_DICTIONARY:
		o.failure = "vector is not valid JSON"
		return o

	var meta: Variant = vector.get("$vector", null)
	if typeof(meta) != TYPE_DICTIONARY:
		o.failure = "missing $vector"
		return o
	if not vector.has("document"):
		o.failure = "missing document"
		return o
	var doc: Variant = vector["document"]

	var kind: Variant = meta.get("kind", null)
	if typeof(kind) != TYPE_STRING or not Validator._SCHEMA_PATHS.has(kind):
		o.failure = "unknown kind %s" % str(kind)
		return o

	var expect: Variant = meta.get("expect", null)
	if expect != "valid" and expect != "invalid":
		o.failure = "bad $vector.expect: %s" % str(expect)
		return o
	var expect_valid: bool = (expect == "valid")
	var exhaustive: bool = meta.get("exhaustive", false) == true

	# The context is stated by the vector, never inferred from `expect`. A runner that decided
	# how to validate by looking at the expected outcome would argue in a circle and pass its
	# own vectors whatever the validator did.
	var ctx := ValidationContext.new()
	var ctx_node: Variant = meta.get("context", null)
	var world_id: Variant = null
	if typeof(ctx_node) == TYPE_DICTIONARY and typeof(ctx_node.get("world_id", null)) == TYPE_STRING:
		world_id = ctx_node["world_id"]
	elif typeof(doc) == TYPE_DICTIONARY and typeof(doc.get("id", null)) == TYPE_STRING:
		world_id = doc["id"]
	if world_id != null:
		ctx.with_world_id(world_id)
	if typeof(ctx_node) == TYPE_DICTIONARY and typeof(ctx_node.get("items", null)) == TYPE_ARRAY:
		ctx.with_items(ctx_node["items"])

	var report = Validator.validate(kind, doc, ctx)
	o.report = report

	var got := {}
	for finding in report.findings:
		got[finding.key()] = true

	if expect_valid:
		if not report.is_ok():
			o.failure = "expected no findings, got: %s" % _render(report)
		return o

	var want := {}
	var errors: Variant = meta.get("errors", [])
	if typeof(errors) == TYPE_ARRAY:
		for e in errors:
			if typeof(e) == TYPE_DICTIONARY:
				want["%s\t%s" % [e.get("code", "?"), e.get("path", "")]] = true

	var missing: Array[String] = []
	for k in want.keys():
		if not got.has(k):
			missing.append(k.replace("\t", " at "))
	var extra: Array[String] = []
	for k in got.keys():
		if not want.has(k):
			extra.append(k.replace("\t", " at "))
	missing.sort()
	extra.sort()

	var why: Array[String] = []
	if not missing.is_empty():
		why.append("expected but not reported: %s" % "; ".join(missing))
	if exhaustive and not extra.is_empty():
		why.append("reported but not expected (vector is exhaustive): %s" % "; ".join(extra))
	o.failure = " | ".join(why)
	return o


static func _render(report) -> String:
	var lines: Array[String] = []
	for f in report.findings:
		lines.append(str(f))
	return "\n        " + "\n        ".join(lines)
