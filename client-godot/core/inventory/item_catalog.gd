extends RefCounted
## Item definitions, for the whole universe rather than for one world.
##
## SPEC §8.2. When the player carries `xianxia_gate:spirit_herb` into `pastoral_village`,
## the village package contains no definition for it. Resolution therefore looks in the live
## catalog first and in the save's embedded snapshot second -- and when neither has it, the
## stack is still kept and rendered as a placeholder.
##
## **Losing a player's item because its defining world is unavailable is a breach of
## *Protection of existing work* and must not happen.** That is the entire reason this class
## has two layers instead of one.

const PLACEHOLDER_COLOR := "#8a8a8a"

## item_id -> definition, from world packages currently known.
var _live: Dictionary = {}
## item_id -> definition, embedded in the save that was loaded.
var _snapshot: Dictionary = {}


func load_from_registry(registry) -> void:
	_live.clear()
	for world_id in registry.ids():
		var doc: Variant = registry.items_doc(world_id)
		if typeof(doc) != TYPE_DICTIONARY:
			continue
		for item in doc.get("items", []):
			if typeof(item) == TYPE_DICTIONARY and typeof(item.get("id", null)) == TYPE_STRING:
				_live[item["id"]] = item


func load_snapshot(item_defs: Variant) -> void:
	_snapshot.clear()
	if typeof(item_defs) != TYPE_DICTIONARY:
		return
	for id in item_defs.keys():
		if typeof(item_defs[id]) == TYPE_DICTIONARY:
			_snapshot[id] = item_defs[id]


## The live catalog wins, so a world author can still fix a typo in an item's name and have
## it take effect on saves written before the fix.
func resolve(item_id: String) -> Variant:
	if _live.has(item_id):
		return _live[item_id]
	if _snapshot.has(item_id):
		return _snapshot[item_id]
	return null


func is_known(item_id: String) -> bool:
	return resolve(item_id) != null


## SPEC §8.3: a save embeds the definition of every item it holds a stack of, so that it
## survives its defining world being unpublished, renamed or deleted.
func snapshot_for(item_ids: Array) -> Dictionary:
	var out := {}
	for id in item_ids:
		var def: Variant = resolve(id)
		if def != null:
			out[id] = def
		else:
			# The item is already unresolvable. Writing a minimal stand-in keeps the save
			# schema-valid and the stack loadable, rather than dropping the player's item to
			# keep the file tidy.
			out[id] = {
				"id": id,
				"display_name": {"en": id},
				"icon": {"color": PLACEHOLDER_COLOR},
			}
	return out


func display_name(item_id: String, locale := "en") -> String:
	var def: Variant = resolve(item_id)
	if def == null:
		return item_id
	return _localized(def.get("display_name", null), locale, item_id)


func icon_color(item_id: String) -> Color:
	var def: Variant = resolve(item_id)
	if def == null:
		return Color(PLACEHOLDER_COLOR)
	var icon: Variant = def.get("icon", null)
	if typeof(icon) == TYPE_DICTIONARY and typeof(icon.get("color", null)) == TYPE_STRING:
		return Color(icon["color"])
	return Color(PLACEHOLDER_COLOR)


func stack_limit(item_id: String) -> int:
	var def: Variant = resolve(item_id)
	if def == null:
		return 99
	return int(def.get("stack_limit", 99))


## Item props are opaque. The catalog hands them back untouched and never reads a key.
func props(item_id: String) -> Dictionary:
	var def: Variant = resolve(item_id)
	if def == null:
		return {}
	var p: Variant = def.get("props", {})
	return p if typeof(p) == TYPE_DICTIONARY else {}


## SPEC §4 resolution order, identical to WorldRuntime's. Duplicated rather than shared
## because the alternative is a "text utils" module that everything depends on; if a third
## caller appears, that is the moment to extract it.
static func _localized(value: Variant, locale: String, fallback: String) -> String:
	if typeof(value) != TYPE_DICTIONARY or value.is_empty():
		return fallback
	if value.has(locale):
		return value[locale]
	var keys: Array = value.keys()
	keys.sort()
	var primary := locale.split("-")[0]
	for k in keys:
		if k.split("-")[0] == primary:
			return value[k]
	if value.has("en"):
		return value["en"]
	return value[keys[0]]
