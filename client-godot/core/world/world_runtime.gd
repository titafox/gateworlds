extends RefCounted
## A loaded world: the scene tree it produced, and the parts of it the game needs to reach.
##
## Holding the portals and pickups here rather than searching the tree for them keeps the
## loader honest: anything the game can interact with had to be built from a whitelisted
## component, so there is no way for an entity to acquire behaviour the loader did not give
## it.

var world_id := ""
var world: Dictionary = {}
var root: Node2D = null
var portals: Array = []
var pickups: Array = []


func bounds() -> Vector2:
	var b: Variant = world.get("bounds", null)
	if typeof(b) != TYPE_DICTIONARY:
		return Vector2(640, 480)
	return Vector2(float(b.get("width", 640)), float(b.get("height", 480)))


func display_name(locale := "en") -> String:
	return _localized(world.get("display_name", null), locale, world_id)


## SPEC §4 resolution order, so that two clients show the same string:
## exact locale, then primary subtag (lexicographically smallest match), then "en", then the
## lexicographically smallest key. The last step is what guarantees a result at all.
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
