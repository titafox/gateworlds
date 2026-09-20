extends RefCounted
## The seam for save migrations.
##
## Empty at 0.1.0 because there is nothing to migrate from. It exists so that the obligation
## is visible rather than remembered: SPEC §2.3 requires every version bump to ship its
## migration, and a version bump proposed without one is not a valid proposal.
##
## When the first migration lands it goes in `STEPS` as "from" -> Callable, and `apply()`
## walks the chain. Writing that walk now, with one entry, is cheaper than discovering later
## that the shape was never designed for more than one hop.

const ProtocolVersion := preload("res://core/protocol/protocol_version.gd")

## "0.1.0" -> func(doc: Dictionary) -> Dictionary, producing the next version.
const STEPS := {}


## Returns { "ok": bool, "doc": Dictionary, "error": String }.
static func apply(doc: Dictionary) -> Dictionary:
	var current := str(doc.get("save_version", ""))
	var seen := {}
	var out := doc

	while current != ProtocolVersion.VERSION_STRING:
		if not STEPS.has(current):
			return {
				"ok": false,
				"doc": out,
				"error": (
					"save is version %s and no migration to %s exists; "
					+ "refusing to guess at a shape this build does not understand"
				) % [current if not current.is_empty() else "<missing>",
					ProtocolVersion.VERSION_STRING],
			}
		if seen.has(current):
			# A cycle would spin forever on a corrupt or hand-edited file.
			return {"ok": false, "doc": out, "error": "migration cycle at %s" % current}
		seen[current] = true
		out = STEPS[current].call(out)
		current = str(out.get("save_version", ""))

	return {"ok": true, "doc": out, "error": ""}
