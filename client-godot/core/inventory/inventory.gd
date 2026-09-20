extends RefCounted
## What the player is carrying.
##
## Belongs to the player, not to a world. Nothing here is cleared when a world is swapped,
## which is why the spirit herb survives the walk back to the village: not a special case,
## simply the absence of one.

signal changed

## Ordered. SPEC §10: this is the player's slot order and must be preserved across
## save/load. Each entry is { "item": String, "count": int, "props": Dictionary }.
var stacks: Array = []


func clear() -> void:
	stacks.clear()
	changed.emit()


func total(item_id: String) -> int:
	var n := 0
	for s in stacks:
		if s["item"] == item_id:
			n += s["count"]
	return n


func is_empty() -> bool:
	return stacks.is_empty()


## Adds `count` of an item, filling existing stacks before opening new ones.
##
## Only a stack with the *same* props is filled. Merging two stacks that differ in props
## would quietly destroy whatever distinguished them, and props are opaque -- this code has
## no way to know what it would be throwing away.
func add(item_id: String, count: int, limit := 99, props: Dictionary = {}) -> void:
	if count <= 0:
		return
	var remaining := count
	var cap: int = maxi(1, limit)

	for s in stacks:
		if remaining <= 0:
			break
		if s["item"] == item_id and s["props"] == props and s["count"] < cap:
			var room: int = cap - s["count"]
			var moved: int = mini(room, remaining)
			s["count"] += moved
			remaining -= moved

	while remaining > 0:
		var chunk: int = mini(cap, remaining)
		stacks.append({"item": item_id, "count": chunk, "props": props.duplicate(true)})
		remaining -= chunk

	changed.emit()


## The shape SPEC §10 stores. Props are written only when non-empty, so a save does not fill
## with noise.
func to_save() -> Array:
	var out: Array = []
	for s in stacks:
		var entry := {"item": s["item"], "count": s["count"]}
		if not s["props"].is_empty():
			entry["props"] = s["props"].duplicate(true)
		out.append(entry)
	return out


## Restores exactly what was saved.
##
## SPEC §10: two stacks may share an item id, and an implementation **must not** silently
## merge them. So this appends verbatim and never calls add().
func from_save(entries: Variant) -> void:
	stacks.clear()
	if typeof(entries) == TYPE_ARRAY:
		for e in entries:
			if typeof(e) != TYPE_DICTIONARY:
				continue
			var props: Variant = e.get("props", {})
			stacks.append({
				"item": str(e.get("item", "")),
				"count": int(e.get("count", 1)),
				"props": props.duplicate(true) if typeof(props) == TYPE_DICTIONARY else {},
			})
	changed.emit()


## Every distinct item id held, for building the save's definition snapshot.
func item_ids() -> Array:
	var seen := {}
	for s in stacks:
		seen[s["item"]] = true
	var out := seen.keys()
	out.sort()
	return out
