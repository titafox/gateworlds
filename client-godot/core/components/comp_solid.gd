extends StaticBody2D
## SPEC §7.2 `solid` -- blocks movement.

const Geometry := preload("res://core/world/geometry.gd")


static func build(params: Dictionary) -> StaticBody2D:
	var body := new()
	var size := Geometry.size(params.get("size", null))
	var offset := Geometry.coord(params.get("offset", null))

	var shape := RectangleShape2D.new()
	shape.size = size

	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Geometry.centre_offset(offset, size)

	body.add_child(collider)
	return body
