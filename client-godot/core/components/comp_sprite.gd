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


static func build(params: Dictionary, base_dir := "") -> Node2D:
	var node := new()
	var size := Geometry.size(params.get("size", null))
	var offset := Geometry.coord(params.get("offset", null))
	node.rect = Rect2(offset, size)
	node.fill = Geometry.color(params.get("color", null))
	node.z_index = int(params.get("z", 0))

	var rel: Variant = params.get("texture", null)
	if typeof(rel) == TYPE_STRING and not base_dir.is_empty():
		node.texture = load_package_image("%s/%s" % [base_dir, rel])
	return node


## Loads an image straight from the file rather than through the resource system.
##
## `load()` only works for files Godot has already imported, which is true of art that
## shipped with the project and false of art that arrived with a world -- and a world that
## arrived over the network is the case this client exists to support. Image.load_from_file
## reads the bytes it was given.
static func load_package_image(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		push_error("cannot read texture %s" % path)
		return null
	return ImageTexture.create_from_image(image)


func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, fill, true)
