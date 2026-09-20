extends RefCounted
## Turning protocol coordinates into engine coordinates, in one place.
##
## SPEC §6.1: an entity's `at` is its **top-left origin**, not its centre, and a component's
## rectangle spans `at + offset` to `at + offset + size`.
##
## Godot's 2D collision shapes are centred on their owner, so every component that builds a
## shape has to convert. Doing that conversion inline in four components is four chances to
## get it wrong in a way that no error would ever report -- the package would simply be laid
## out differently here than in another client. It lives here instead, with tests.

## The component's rectangle in world coordinates, top-left anchored.
static func rect_for(at: Vector2, offset: Vector2, size: Vector2) -> Rect2:
	return Rect2(at + offset, size)


## Where to put a centred collision shape so that it covers `rect_for(...)`.
## Relative to the entity's own position, because the shape hangs off the entity node.
static func centre_offset(offset: Vector2, size: Vector2) -> Vector2:
	return offset + size * 0.5


## Reads an `[x, y]` coordinate pair from a validated document.
##
## Validation has already established these are two numbers in range, so this does not
## re-report errors -- it returns the zero vector for anything malformed, which can only
## happen if an unvalidated document reached the loader.
static func coord(value: Variant) -> Vector2:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return Vector2.ZERO
	return Vector2(float(value[0]), float(value[1]))


## Reads a `[w, h]` size pair.
static func size(value: Variant) -> Vector2:
	if typeof(value) != TYPE_ARRAY or value.size() < 2:
		return Vector2.ONE
	return Vector2(float(value[0]), float(value[1]))


## Parses `#rrggbb` or `#rrggbbaa`. Validation has already checked the shape.
static func color(value: Variant, fallback := Color.MAGENTA) -> Color:
	if typeof(value) != TYPE_STRING or not (value as String).begins_with("#"):
		return fallback
	return Color.html(value)
