extends RefCounted
## Unit tests mirroring the Rust ones in `server/crates/gateworlds-protocol/src/*.rs`.
##
## Kept parallel deliberately: when the two implementations disagree, the first question is
## always "do they even test the same thing?", and the answer should be readable.

const Codes := preload("res://core/protocol/codes.gd")
const Report := preload("res://core/protocol/report.gd")
const JsonSchema := preload("res://core/protocol/json_schema.gd")
const ProtocolVersion := preload("res://core/protocol/protocol_version.gd")
const ResPath := preload("res://core/protocol/res_path.gd")
const Validator := preload("res://core/protocol/validator.gd")


static func run(t) -> void:
	_version(t)
	_respath(t)
	_findings(t)
	_schema_subset(t)


static func _version(t) -> void:
	t.group("version")
	for s in ["1", "1.2", "1.2.3.4", "01.2.3", "1.02.3", "1.2.3-rc1", "1.2.3+build", "a.b.c", ""]:
		t.ok(ProtocolVersion.parse(s).is_empty(), 'should reject "%s"' % s)

	t.eq(ProtocolVersion.parse("0.1.0"), [0, 1, 0], "parses a plain version")
	t.ok(ProtocolVersion.accepts([0, 1, 0]), "accepts its own version")
	t.ok(ProtocolVersion.accepts([0, 1, 7]), "patch is ignored")
	t.ok(not ProtocolVersion.accepts([0, 2, 0]), "a 0.1 validator must reject 0.2")
	t.ok(not ProtocolVersion.accepts([0, 0, 9]), "rejects an older minor pre-1.0")
	t.ok(not ProtocolVersion.accepts([1, 0, 0]), "rejects a newer major")
	t.eq(ProtocolVersion.parse(ProtocolVersion.VERSION_STRING),
		[ProtocolVersion.MAJOR, ProtocolVersion.MINOR, ProtocolVersion.PATCH],
		"the string and the constants agree")


static func _respath(t) -> void:
	t.group("respath")
	for p in ["art/e.png", "a", "icons/herb.png", "a/b/c/d_e-f.2.png", "_private/x.ogg"]:
		t.eq(ResPath.check(p), "", 'should accept "%s"' % p)

	t.eq(ResPath.check("../../../etc/passwd"), ResPath.BAD_FIRST, "rejects leading traversal")
	t.eq(ResPath.check("/etc/passwd"), ResPath.BAD_FIRST, "rejects an absolute path")
	t.ok(ResPath.check("res://core/save_manager.gd").contains('":"'),
		"rejects an engine URI scheme on the colon")
	t.ok(ResPath.check("https://example.invalid/p.png").contains('":"'), "rejects a URL")
	t.ok(ResPath.check("C:\\Windows\\System32").contains('":"'), "rejects a Windows path")
	t.eq(ResPath.check("art/../../secret.png"), ResPath.PARENT_SEGMENT,
		"rejects traversal that does not start the path")
	t.eq(ResPath.check("art//e.png"), ResPath.EMPTY_SEGMENT, "rejects an empty segment")
	t.eq(ResPath.check("art/"), ResPath.TRAILING, "rejects a trailing slash")
	t.eq(ResPath.check("art/e."), ResPath.TRAILING, "rejects a trailing dot")
	t.eq(ResPath.check("./x.png"), ResPath.BAD_FIRST, "rejects a leading dot segment")
	t.eq(ResPath.check(""), ResPath.EMPTY, "rejects an empty path")
	t.eq(ResPath.check("a".repeat(256)), ResPath.TOO_LONG, "rejects an overlong path")
	t.eq(ResPath.check("a".repeat(255)), "", "accepts exactly 255 characters")


static func _findings(t) -> void:
	t.group("findings")
	t.ok(Codes.is_ancestor("/entities/1", "/entities/1/components/0"), "direct ancestry")
	t.ok(Codes.is_ancestor("", "/anything"), "root is an ancestor of everything")
	t.ok(not Codes.is_ancestor("/entities/1", "/entities/10"),
		"ancestry is segment-wise, not string prefix")
	t.ok(not Codes.is_ancestor("/entities/1", "/entities/1"), "a path is not its own ancestor")
	t.ok(not Codes.is_ancestor("/a/b", "/a"), "a descendant is not an ancestor")

	var r = Report.new()
	r.push(Codes.SCHEMA_VIOLATION, "/entities/0/components/0/texture", "pattern")
	r.push(Codes.INVALID_RESOURCE_PATH, "/entities/0/components/0/texture", "escapes package")
	r.finish()
	t.eq(r.findings.size(), 1, "a specific finding suppresses a generic one at the same path")
	t.eq(r.findings[0].code, Codes.INVALID_RESOURCE_PATH, "the specific one survives")

	r = Report.new()
	r.push(Codes.SCHEMA_VIOLATION, "/entities/1/components/0", "oneOf")
	r.push(Codes.UNKNOWN_COMPONENT_TYPE, "/entities/1/components/0/type", "summon_dragon")
	r.finish()
	t.eq(r.findings.size(), 1, "a specific finding suppresses a generic one at an ancestor")

	r = Report.new()
	r.push(Codes.SCHEMA_VIOLATION, "/spawns", "missing default")
	r.push(Codes.DUPLICATE_ID, "/entities/1/id", "twin")
	r.finish()
	t.eq(r.findings.size(), 2, "an unrelated schema violation survives")

	t.eq(Codes.escape_segment("a/b"), "a~1b", "RFC 6901 escaping of /")
	t.eq(Codes.escape_segment("a~b"), "a~0b", "RFC 6901 escaping of ~")


static func _schema_subset(t) -> void:
	t.group("schema subset")
	# A validator that silently ignores a keyword is a validator that silently stops checking
	# something. If a schema ever grows a keyword this subset does not implement, this fails
	# rather than quietly passing everything.
	for kind in [Validator.KIND_WORLD, Validator.KIND_ITEMS, Validator.KIND_SAVE]:
		var schema := Validator.schema_for(kind)
		t.ok(not schema.is_empty(), "%s schema loads" % kind)
		var unknown := JsonSchema.unsupported_keywords(schema, {})
		t.eq(unknown, [], "%s schema uses only keywords this subset implements" % kind)

	# Godot's JSON parser and serde_json disagree about when a whole number becomes a float.
	# Leaning on the parser's choice would be a divergence waiting to happen, so the integer
	# check looks at the value, not at how it was spelled.
	var int_schema := {"type": "integer"}
	t.ok(JsonSchema.validate(int_schema, 5).is_empty(), "an int is an integer")
	t.ok(JsonSchema.validate(int_schema, 5.0).is_empty(), "a whole float is an integer")
	t.ok(not JsonSchema.validate(int_schema, 5.5).is_empty(), "a fractional float is not")
	t.ok(not JsonSchema.validate(int_schema, "5").is_empty(), "a numeric string is not")
	t.ok(not JsonSchema.validate({"type": "number"}, true).is_empty(), "a bool is not a number")

	# JSON Schema uses ECMA-262 regular expressions, where `$` without the `m` flag means end
	# of input. PCRE2's `$` also matches before a final newline, so without rewriting, this
	# implementation accepted a slug the Rust and browser validators both rejected -- a
	# package the server refuses and a client loads.
	var slug := {"type": "string", "pattern": "^[a-z0-9]([a-z0-9_]*[a-z0-9])?$"}
	t.ok(JsonSchema.validate(slug, "abc").is_empty(), "a plain slug is accepted")
	t.ok(not JsonSchema.validate(slug, "abc\n").is_empty(),
		"a trailing newline is rejected, as ECMA-262 requires")
	t.ok(not JsonSchema.validate(slug, "abc\ndef").is_empty(), "an embedded newline too")

	# The rewrite must not touch a dollar that is meant literally.
	t.eq(JsonSchema._ecma_anchors("^a$"), "^a\\z", "a trailing anchor becomes \\z")
	t.eq(JsonSchema._ecma_anchors("^a\\$b$"), "^a\\$b\\z", "an escaped dollar is left alone")
	t.eq(JsonSchema._ecma_anchors("^[a$]+$"), "^[a$]+\\z", "a dollar in a character class is literal")
	t.ok(JsonSchema.validate({"type": "string", "pattern": "^[a$]+$"}, "a$a").is_empty(),
		"and still matches as a literal")
