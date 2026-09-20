extends RefCounted
## Where worlds come from.
##
## The interface exists so that "on disk", "from a registry over HTTP" and whatever comes
## later are interchangeable to everything above it. A source hands back **raw documents**
## and never validated ones: validation belongs to the registry, in one place, so that a
## future source cannot accidentally become a way to skip it.

## Returns the world ids this source can offer.
func list_ids() -> Array:
	push_error("list_ids() not implemented")
	return []


## Returns { "world": Dictionary, "items": Dictionary|null } or null when absent.
## The documents are unvalidated. Callers must not use them directly.
func fetch(_world_id: String) -> Variant:
	push_error("fetch() not implemented")
	return null
