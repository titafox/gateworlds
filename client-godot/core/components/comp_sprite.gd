extends Node2D
## SPEC §7.1 `sprite` -- visual representation.
##
## Draws a flat rectangle. That is the whole of the protocol's visual vocabulary at 0.1.0,
## and deliberately so: richer drawing means more engine surface reachable from data, and
## every addition has to be argued for through governance rather than smuggled in.

const Geometry := preload("res://core/world/geometry.gd")

var rect := Rect2()
var fill := Color.MAGENTA
var texture: Texture2D = null


static func build(params: Dictionary) -> Node2D:
	var node := new()
	var size := Geometry.size(params.get("size", null))
	var offset := Geometry.coord(params.get("offset", null))
	node.rect = Rect2(offset, size)
	node.fill = Geometry.color(params.get("color", null))
	node.z_index = int(params.get("z", 0))
	return node


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, fill, true)
