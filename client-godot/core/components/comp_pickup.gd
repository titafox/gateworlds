extends Area2D
## SPEC §7.4 `pickup` -- grants an item when collected.
##
## Generic, not a genre: a spirit herb, a carrot and a data shard are this component with
## different item ids.

signal collected(entity_id: String, item: String, count: int, once: bool)

const Geometry := preload("res://core/world/geometry.gd")

var item := ""
var count := 1
var once := true
var entity_id := ""


static func build(params: Dictionary) -> Area2D:
	var area := new()
	area.item = str(params.get("item", ""))
	area.count = int(params.get("count", 1))
	area.once = params.get("once", true) == true

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
	collected.emit(entity_id, item, count, once)
