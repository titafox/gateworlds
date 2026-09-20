extends Area2D
## SPEC §7.3 `portal` -- travel to another world.
##
## The component names a destination and nothing else. *How* travel happens is the client's
## business, and a world that could describe the mechanism would be describing behaviour,
## which is what keeps the protocol data-only.

signal entered(target_world: String, target_spawn: String)

const Geometry := preload("res://core/world/geometry.gd")

var target_world := ""
var target_spawn := "default"


static func build(params: Dictionary) -> Area2D:
	var area := new()
	area.target_world = str(params.get("target_world", ""))
	area.target_spawn = str(params.get("target_spawn", "default"))

	var size := Geometry.size(params.get("size", null))
	var offset := Geometry.coord(params.get("offset", null))

	var shape := RectangleShape2D.new()
	shape.size = size

	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Geometry.centre_offset(offset, size)

	area.add_child(collider)
	area.monitoring = true
	area.body_entered.connect(area._on_body_entered)
	return area


func _on_body_entered(_body: Node2D) -> void:
	entered.emit(target_world, target_spawn)
