extends CharacterBody2D
## The player.
##
## Movement and a collision box. No health, no level, no attack, no stats of any kind --
## SPEC §1: the protocol does not define them, so neither does the thing that walks around
## in it. A world that wants those things carries them in `props` and a future component
## gives them meaning; the player does not come with them pre-installed.

const CompSprite := preload("res://core/components/comp_sprite.gd")

const SIZE := Vector2(16, 16)
const SPEED := 130.0


static func create() -> CharacterBody2D:
	var body := new()
	body.name = "Player"

	var shape := RectangleShape2D.new()
	shape.size = SIZE

	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)

	# Drawn by the same component the worlds use, and offset so the square is centred on the
	# body -- a CharacterBody2D is positioned by its centre, everything in the protocol is
	# anchored top-left.
	var visual := CompSprite.build({
		"size": [int(SIZE.x), int(SIZE.y)],
		"offset": [int(-SIZE.x / 2), int(-SIZE.y / 2)],
		"color": "#f2e9d8",
		"z": 10,
	})
	visual.name = "Visual"
	body.add_child(visual)

	return body


## Places the player so that its **top-left** sits on `at`.
##
## SPEC §6.1 anchors everything top-left, but a CharacterBody2D is positioned by its centre.
## Getting this wrong puts the player half a body off every spawn point -- visible, but easy
## to mistake for a content mistake rather than a client one.
func place_top_left_at(at: Vector2) -> void:
	position = at + SIZE * 0.5


func top_left() -> Vector2:
	return position - SIZE * 0.5


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
