extends RefCounted
## Procedural checks and orchestration.
##
## Counterpart to `server/crates/gateworlds-protocol/src/validate.rs`. The schema catches
## shape; these catch the rules a schema cannot express: version acceptance, the closed
## component whitelist, resource paths, uniqueness, reference resolution, item namespacing
## and bounds.

const Codes := preload("res://core/protocol/codes.gd")
const Report := preload("res://core/protocol/report.gd")
const ValidationContext := preload("res://core/protocol/validation_context.gd")
const JsonSchema := preload("res://core/protocol/json_schema.gd")
const ProtocolVersion := preload("res://core/protocol/protocol_version.gd")
const ResPath := preload("res://core/protocol/res_path.gd")

## The closed component whitelist, SPEC §7. Adding to this is a protocol change.
const COMPONENT_TYPES := ["sprite", "solid", "portal", "pickup"]

const KIND_WORLD := "world"
const KIND_ITEMS := "items"
const KIND_SAVE := "save"

const _SCHEMA_PATHS := {
	KIND_WORLD: "res://protocol/world-v0.1.schema.json",
	KIND_ITEMS: "res://protocol/items-v0.1.schema.json",
	KIND_SAVE: "res://protocol/save-v0.1.schema.json",
}

static var _schema_cache := {}


static func version_field(kind: String) -> String:
	return "save_version" if kind == KIND_SAVE else "protocol_version"


static func schema_for(kind: String) -> Dictionary:
	if not _schema_cache.has(kind):
		var path: String = _SCHEMA_PATHS[kind]
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("cannot open %s" % path)
			return {}
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		_schema_cache[kind] = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _schema_cache[kind]


static func validate(kind: String, doc: Variant, ctx) -> Report:
	var report := Report.new()

	if typeof(doc) != TYPE_DICTIONARY:
		report.push(Codes.SCHEMA_VIOLATION, "", "the document is not a JSON object")
		return report.finish()

	# SPEC §2.2: stop here on an unsupported version. Every later check would run against a
	# document shape this implementation does not claim to understand, and would report noise
	# the creator cannot act on.
	var version_problem: Variant = ProtocolVersion.check(doc, version_field(kind))
	if version_problem != null:
		report.findings.append(version_problem)
		return report.finish()

	report.extend(JsonSchema.validate(schema_for(kind), doc))

	match kind:
		KIND_WORLD:
			_check_world(doc, ctx, report)
		KIND_ITEMS:
			_check_items(doc, ctx, report)
		KIND_SAVE:
			_check_save(doc, report)

	return report.finish()


# ------------------------------------------------------------------------------- world

static func _check_world(doc: Dictionary, ctx, r) -> void:
	var bounds: Variant = doc.get("bounds", null)
	var w: Variant = null
	var h: Variant = null
	if typeof(bounds) == TYPE_DICTIONARY:
		w = bounds.get("width", null)
		h = bounds.get("height", null)

	var spawns: Variant = doc.get("spawns", null)
	if typeof(spawns) == TYPE_DICTIONARY:
		for name in spawns.keys():
			if typeof(spawns[name]) == TYPE_DICTIONARY:
				_check_in_bounds(spawns[name].get("at", null), w, h, "/spawns/%s/at" % name, r)

	var entities: Variant = doc.get("entities", null)
	if typeof(entities) != TYPE_ARRAY:
		return

	var seen_ids := {}
	for i in entities.size():
		var entity: Variant = entities[i]
		if typeof(entity) != TYPE_DICTIONARY:
			continue

		var eid: Variant = entity.get("id", null)
		if typeof(eid) == TYPE_STRING:
			if seen_ids.has(eid):
				r.push(
					Codes.DUPLICATE_ID, "/entities/%d/id" % i,
					'entity id "%s" is already used at /entities/%d' % [eid, seen_ids[eid]]
				)
			else:
				seen_ids[eid] = i

		_check_in_bounds(entity.get("at", null), w, h, "/entities/%d/at" % i, r)

		var components: Variant = entity.get("components", null)
		if typeof(components) != TYPE_ARRAY:
			continue

		var seen_types := {}
		for j in components.size():
			var comp: Variant = components[j]
			if typeof(comp) != TYPE_DICTIONARY:
				continue
			var base := "/entities/%d/components/%d" % [i, j]
			var ty: Variant = comp.get("type", null)
			if typeof(ty) != TYPE_STRING:
				continue

			if not COMPONENT_TYPES.has(ty):
				r.push(
					Codes.UNKNOWN_COMPONENT_TYPE, base + "/type",
					('"%s" is not in the component whitelist (%s); the set is closed and '
						+ "adding to it is a protocol change (SPEC §7)")
					% [ty, ", ".join(COMPONENT_TYPES)]
				)
				continue

			if seen_types.has(ty):
				r.push(
					Codes.DUPLICATE_ID, base + "/type",
					('this entity already carries a "%s" component at '
						+ "/entities/%d/components/%d; draw and trigger order would be undefined")
					% [ty, i, seen_types[ty]]
				)
			else:
				seen_types[ty] = j

			if ty == "sprite":
				_check_resource(comp.get("texture", null), base + "/texture", r)
			if ty == "pickup":
				var item: Variant = comp.get("item", null)
				if typeof(item) == TYPE_STRING and not ctx.known_items.has(item):
					r.push(
						Codes.UNRESOLVED_REFERENCE, base + "/item",
						('"%s" is not defined in this package; in 0.1.0 a pickup must '
							+ "reference an item of its own package (SPEC §3.2)") % item
					)


# ------------------------------------------------------------------------------- items

static func _check_items(doc: Dictionary, ctx, r) -> void:
	var items: Variant = doc.get("items", null)
	if typeof(items) != TYPE_ARRAY:
		return

	var seen := {}
	for i in items.size():
		var item: Variant = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var path := "/items/%d/id" % i
		var id: Variant = item.get("id", null)
		if typeof(id) == TYPE_STRING:
			if seen.has(id):
				r.push(
					Codes.DUPLICATE_ID, path,
					'item id "%s" is already defined at /items/%d' % [id, seen[id]]
				)
			else:
				seen[id] = i

			# SPEC §3.2: a world may only define items in its own namespace, or one world
			# could shadow another's items.
			var colon: int = id.find(":")
			if not ctx.world_id.is_empty() and colon > 0:
				var ns: String = id.substr(0, colon)
				if ns != ctx.world_id:
					r.push(
						Codes.INVALID_ITEM_NAMESPACE, path,
						('namespace "%s" does not match the defining world "%s"; a world '
							+ "may only define items in its own namespace")
						% [ns, ctx.world_id]
					)

		var icon: Variant = item.get("icon", null)
		if typeof(icon) == TYPE_DICTIONARY:
			_check_resource(icon.get("texture", null), "/items/%d/icon/texture" % i, r)


# -------------------------------------------------------------------------------- save

static func _check_save(doc: Dictionary, r) -> void:
	var defs: Variant = doc.get("item_defs", null)
	var have: Dictionary = defs if typeof(defs) == TYPE_DICTIONARY else {}

	var inventory: Variant = doc.get("inventory", null)
	if typeof(inventory) != TYPE_DICTIONARY:
		return
	var stacks: Variant = inventory.get("stacks", null)
	if typeof(stacks) != TYPE_ARRAY:
		return

	for i in stacks.size():
		var stack: Variant = stacks[i]
		if typeof(stack) != TYPE_DICTIONARY:
			continue
		var item: Variant = stack.get("item", null)
		if typeof(item) == TYPE_STRING and not have.has(item):
			r.push(
				Codes.UNRESOLVED_REFERENCE, "/inventory/stacks/%d/item" % i,
				('no definition for "%s" in item_defs; a save must embed the definition of '
					+ "every item it holds, so that it survives its defining world being "
					+ "unpublished (SPEC §8.3)") % item
			)


# ------------------------------------------------------------------------------ shared

static func _check_in_bounds(at: Variant, w: Variant, h: Variant, path: String, r) -> void:
	if typeof(at) != TYPE_ARRAY or at.size() < 2:
		return
	if not (typeof(w) == TYPE_INT or typeof(w) == TYPE_FLOAT):
		return
	if not (typeof(h) == TYPE_INT or typeof(h) == TYPE_FLOAT):
		return
	var x: Variant = at[0]
	var y: Variant = at[1]
	if not (typeof(x) == TYPE_INT or typeof(x) == TYPE_FLOAT):
		return
	if not (typeof(y) == TYPE_INT or typeof(y) == TYPE_FLOAT):
		return
	if x < 0 or y < 0 or x > w or y > h:
		r.push(
			Codes.VALUE_OUT_OF_RANGE, path,
			"[%s, %s] lies outside the world bounds %sx%s" % [str(x), str(y), str(w), str(h)]
		)


static func _check_resource(value: Variant, path: String, r) -> void:
	if typeof(value) != TYPE_STRING:
		return
	var why := ResPath.check(value)
	if not why.is_empty():
		r.push(Codes.INVALID_RESOURCE_PATH, path, why)
