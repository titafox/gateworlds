extends RefCounted
## Maps a whitelisted component type name to the engine code that implements it.
##
## This is the only bridge from world data to executable behaviour, and it is a lookup in a
## fixed table -- never a path, a class name or anything else a package could influence. A
## world says "I want a portal"; it cannot say how a portal works.
##
## Adding an entry is a protocol change (SPEC §7) and needs a schema change, a conformance
## vector and an implementation here. That friction is the feature.

const CompPickup := preload("res://core/components/comp_pickup.gd")
const CompPortal := preload("res://core/components/comp_portal.gd")
const CompSolid := preload("res://core/components/comp_solid.gd")
const CompSprite := preload("res://core/components/comp_sprite.gd")

const _BUILDERS := {
	"sprite": CompSprite,
	"solid": CompSolid,
	"portal": CompPortal,
	"pickup": CompPickup,
}


static func supported() -> Array:
	var keys := _BUILDERS.keys()
	keys.sort()
	return keys


static func build(type_name: String, params: Dictionary) -> Node:
	if not _BUILDERS.has(type_name):
		# Unreachable for a validated package: the validator rejects unknown types before a
		# document ever reaches the loader. Kept as a hard stop rather than a silent skip, so
		# that a gap between the whitelist and this table cannot quietly become a missing node.
		push_error("no builder for component type %s" % type_name)
		return null
	return _BUILDERS[type_name].build(params)
