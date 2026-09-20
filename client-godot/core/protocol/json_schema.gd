extends RefCounted
## A JSON Schema validator covering exactly the subset that `protocol/*.schema.json` uses.
##
## Godot ships no JSON Schema library, so this exists. It is deliberately **not** a general
## Draft 2020-12 implementation: everything it does not support, it refuses loudly (see
## `unsupported_keywords`), because a validator that silently ignores a keyword is a
## validator that silently stops checking something.
##
## This is the single most likely place for the two implementations to diverge, which is
## precisely what `protocol/conformance/` exists to catch: the Rust validator and this one
## must produce the same error code at the same JSON Pointer for all 27 vectors.

const Codes := preload("res://core/protocol/codes.gd")
const Finding := preload("res://core/protocol/finding.gd")

## Keywords this subset understands. Anything else in a schema is a bug in the schema or a
## gap here, and either way must not pass unnoticed.
const KNOWN_KEYWORDS := [
	"$schema", "$id", "title", "description", "default", "$defs", "$ref",
	"type", "const", "required", "properties", "additionalProperties", "propertyNames",
	"minProperties", "maxProperties", "minLength", "maxLength", "pattern",
	"minimum", "maximum", "minItems", "maxItems", "items", "oneOf", "not",
]

static var _regex_cache := {}


static func _regex(pattern: String) -> RegEx:
	if not _regex_cache.has(pattern):
		_regex_cache[pattern] = RegEx.create_from_string(pattern)
	return _regex_cache[pattern]


## Returns every keyword used anywhere in `schema` that this subset does not implement.
## The test suite asserts this is empty for all three shipped schemas.
##
## The walk is schema-aware rather than a blind recursion: under `properties` and `$defs`
## the keys are *names*, not keywords, and `const`/`default` hold arbitrary data that must
## not be read as a schema at all. A naive walk reports every field name in the protocol as
## an unsupported keyword, which is both useless and alarming.
static func unsupported_keywords(schema: Variant, found: Dictionary = {}) -> Array:
	_scan(schema, found)
	var out := found.keys()
	out.sort()
	return out


static func _scan(schema: Variant, found: Dictionary) -> void:
	if typeof(schema) != TYPE_DICTIONARY:
		return
	for k in schema.keys():
		if not KNOWN_KEYWORDS.has(k):
			found[k] = true
		var v: Variant = schema[k]
		match k:
			"properties", "$defs":
				if typeof(v) == TYPE_DICTIONARY:
					for name in v.keys():
						_scan(v[name], found)
			"items", "additionalProperties", "propertyNames", "not":
				_scan(v, found)
			"oneOf":
				if typeof(v) == TYPE_ARRAY:
					for branch in v:
						_scan(branch, found)
			_:
				# required / const / default / scalars: data, not schemas.
				pass


## Validates `instance` against `schema`. Returns an Array of Finding.
static func validate(schema: Dictionary, instance: Variant) -> Array:
	var out: Array = []
	_check(schema, instance, "", schema, out)
	return out


static func _resolve(ref: String, root: Dictionary) -> Dictionary:
	# Only local pointers appear in these schemas, and only local pointers are accepted:
	# following an external $ref would mean fetching a schema at validation time.
	if not ref.begins_with("#/"):
		push_error("unsupported $ref: %s" % ref)
		return {}
	var node: Variant = root
	for raw in ref.substr(2).split("/", true):
		var seg := raw.replace("~1", "/").replace("~0", "~")
		if typeof(node) != TYPE_DICTIONARY or not node.has(seg):
			push_error("unresolvable $ref: %s" % ref)
			return {}
		node = node[seg]
	return node if typeof(node) == TYPE_DICTIONARY else {}


static func _violation(out: Array, path: String, detail: String) -> void:
	out.append(Finding.new(Codes.SCHEMA_VIOLATION, path, detail))


static func _type_matches(want: String, v: Variant) -> bool:
	match want:
		"object":
			return typeof(v) == TYPE_DICTIONARY
		"array":
			return typeof(v) == TYPE_ARRAY
		"string":
			return typeof(v) == TYPE_STRING
		"boolean":
			return typeof(v) == TYPE_BOOL
		"null":
			return typeof(v) == TYPE_NIL
		"number":
			return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
		"integer":
			# JSON Schema: a number with zero fractional part is an integer, however it was
			# spelled. Godot's JSON parser and serde_json disagree about when a whole number
			# becomes a float, so leaning on the parser's choice here would be a divergence
			# waiting to happen.
			if typeof(v) == TYPE_INT:
				return true
			return typeof(v) == TYPE_FLOAT and is_equal_approx(v, floorf(v))
	return false


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## True when `instance` satisfies `schema` with no findings. Used for oneOf / not, where
## only the verdict matters.
static func _satisfies(schema: Dictionary, instance: Variant, root: Dictionary) -> bool:
	var scratch: Array = []
	_check(schema, instance, "", root, scratch)
	return scratch.is_empty()


static func _check(schema: Dictionary, instance: Variant, path: String, root: Dictionary, out: Array) -> void:
	if schema.has("$ref"):
		_check(_resolve(schema["$ref"], root), instance, path, root, out)
		# Every schema here is either a bare $ref or a plain schema, never both.
		return

	if schema.has("type") and not _type_matches(schema["type"], instance):
		_violation(out, path, "expected type %s" % schema["type"])
		return

	if schema.has("const") and instance != schema["const"]:
		_violation(out, path, 'expected the constant "%s"' % str(schema["const"]))
		return

	# oneOf reports a single failure at its own location and does not descend, so a creator
	# is told "this component is not valid" rather than handed four parallel explanations of
	# why it is not each of the four things it could have been.
	if schema.has("oneOf"):
		var matched := 0
		for branch in schema["oneOf"]:
			if _satisfies(branch, instance, root):
				matched += 1
		if matched != 1:
			_violation(
				out, path,
				"matched %d of the %d allowed shapes; exactly one is required"
				% [matched, schema["oneOf"].size()]
			)
			return

	if schema.has("not") and _satisfies(schema["not"], instance, root):
		_violation(out, path, "matched a shape that is explicitly disallowed")
		return

	match typeof(instance):
		TYPE_STRING:
			_check_string(schema, instance, path, out)
		TYPE_DICTIONARY:
			_check_object(schema, instance, path, root, out)
		TYPE_ARRAY:
			_check_array(schema, instance, path, root, out)
		TYPE_INT, TYPE_FLOAT:
			_check_number(schema, instance, path, out)


static func _check_string(schema: Dictionary, s: String, path: String, out: Array) -> void:
	if schema.has("minLength") and s.length() < int(schema["minLength"]):
		_violation(out, path, "shorter than %d characters" % int(schema["minLength"]))
	if schema.has("maxLength") and s.length() > int(schema["maxLength"]):
		_violation(out, path, "longer than %d characters" % int(schema["maxLength"]))
	if schema.has("pattern"):
		var re := _regex(schema["pattern"])
		if re == null or re.search(s) == null:
			_violation(out, path, 'does not match the pattern "%s"' % schema["pattern"])


static func _check_number(schema: Dictionary, n: Variant, path: String, out: Array) -> void:
	if schema.has("minimum") and _is_number(schema["minimum"]) and n < schema["minimum"]:
		_violation(out, path, "below the minimum %s" % str(schema["minimum"]))
	if schema.has("maximum") and _is_number(schema["maximum"]) and n > schema["maximum"]:
		_violation(out, path, "above the maximum %s" % str(schema["maximum"]))


static func _check_array(schema: Dictionary, arr: Array, path: String, root: Dictionary, out: Array) -> void:
	if schema.has("minItems") and arr.size() < int(schema["minItems"]):
		_violation(out, path, "fewer than %d items" % int(schema["minItems"]))
	if schema.has("maxItems") and arr.size() > int(schema["maxItems"]):
		_violation(out, path, "more than %d items" % int(schema["maxItems"]))
	if schema.has("items"):
		for i in arr.size():
			_check(schema["items"], arr[i], "%s/%d" % [path, i], root, out)


static func _check_object(schema: Dictionary, obj: Dictionary, path: String, root: Dictionary, out: Array) -> void:
	if schema.has("minProperties") and obj.size() < int(schema["minProperties"]):
		_violation(out, path, "fewer than %d properties" % int(schema["minProperties"]))
	if schema.has("maxProperties") and obj.size() > int(schema["maxProperties"]):
		_violation(out, path, "more than %d properties" % int(schema["maxProperties"]))

	for name in schema.get("required", []):
		if not obj.has(name):
			_violation(out, path, 'missing the required property "%s"' % name)

	if schema.has("propertyNames"):
		for name in obj.keys():
			if not _satisfies(schema["propertyNames"], name, root):
				_violation(out, path, 'the property name "%s" is not allowed here' % name)

	var props: Dictionary = schema.get("properties", {})
	var extra: Variant = schema.get("additionalProperties", null)

	for name in obj.keys():
		var child := "%s/%s" % [path, Codes.escape_segment(name)]
		if props.has(name):
			_check(props[name], obj[name], child, root, out)
		elif typeof(extra) == TYPE_BOOL and not extra:
			# SPEC §9 leans on this: a package trying to smuggle a behaviour hook fails
			# validation instead of being quietly stripped, and the creator is told which
			# field did it.
			out.append(Finding.new(
				Codes.UNKNOWN_FIELD,
				child,
				('"%s" is not defined by the schema; unknown fields are rejected, '
					+ "never ignored (SPEC §9)") % name
			))
		elif typeof(extra) == TYPE_DICTIONARY:
			_check(extra, obj[name], child, root, out)
