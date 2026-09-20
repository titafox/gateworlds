extends SceneTree
## Drives the real game and photographs it.
##
## The milestone's acceptance criterion is "walk around, and go between the two worlds and
## back". No headless assertion can honestly claim that, so this presses the actual movement
## keys, lets the actual portal triggers fire, and saves what the viewport actually drew.
##
## Steps are driven by the player's position rather than by elapsed time. A timed
## walkthrough that misses its target reports the same "done" as one that arrives, which is
## how the first version of this file quietly walked straight past the portal.

const Main := preload("res://main.gd")

var main: Node2D
var shots := ""
var step := 0
var step_time := 0.0
var failures: Array[String] = []
var pending_shot := ""
var pending_frames := 0
var log_lines: Array[String] = []


func _initialize() -> void:
	shots = OS.get_environment("GW_SHOTS")
	main = Main.new()
	root.add_child(main)


func _note(s: String) -> void:
	log_lines.append(s)
	print(s)


## Captures a few frames later, never immediately.
##
## `root.get_texture()` hands back the last frame the renderer drew, not the state the game
## is in right now. Shooting at the instant a world swaps therefore photographs the world
## being left -- which would illustrate "the portal works" with a picture of it not working.
func _shot(name: String) -> void:
	pending_shot = name
	pending_frames = 3


func _hold(dirs: Array) -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		if dirs.has(a):
			Input.action_press(a)
		else:
			Input.action_release(a)


func _advance(name: String) -> void:
	_hold([])
	step += 1
	step_time = 0.0
	if not name.is_empty():
		_shot(name)


func _timed_out(what: String, limit: float) -> bool:
	if step_time < limit:
		return false
	failures.append("%s: gave up after %.1fs (player at %s, world %s)"
		% [what, limit, main.player.top_left(), main.runtime.world_id])
	_advance("")
	return true


func _process(delta: float) -> bool:
	if pending_frames > 0:
		pending_frames -= 1
		if pending_frames == 0 and not pending_shot.is_empty():
			root.get_texture().get_image().save_png("%s/%s.png" % [shots, pending_shot])
			pending_shot = ""
		return false

	step_time += delta
	var p: Vector2 = main.player.top_left()

	match step:
		0:
			if step_time > 0.4:
				# Opened here rather than in _initialize: the game's own _ready has not run
				# at that point, so there is no HUD to open yet.
				main.hud.toggle_inventory()
				_note("1. start           world=%s  top_left=%s" % [main.runtime.world_id, p])
				if main.runtime.world_id != "pastoral_village":
					failures.append("did not start in the village")
				_advance("01_village_spawn")
		1:
			# Down-left into the pond, to show that `solid` actually stops the player.
			_hold(["move_left", "move_down"])
			if step_time > 1.6:
				_note("2. walked to pond  top_left=%s" % p)
				_advance("02_village_walked")
		2:
			# Line up with the portal band (y 216..264) before heading east.
			_hold(["move_up"])
			if p.y <= 234.0:
				_note("3. lined up        top_left=%s" % p)
				_advance("")
			else:
				_timed_out("lining up with the portal", 6.0)
		3:
			_hold(["move_right"])
			if main.runtime.world_id == "xianxia_gate":
				_note("4. through portal  world=%s  top_left=%s" % [main.runtime.world_id, p])
				_advance("03_xianxia_arrived")
			else:
				_timed_out("walking east into the portal", 8.0)
		4:
			# The herb sits at (420, 300); the arrival spawn is (110, 228).
			var d := Vector2(420, 300) - p
			_hold([
				"move_right" if d.x > 4 else ("move_left" if d.x < -4 else ""),
				"move_down" if d.y > 4 else ("move_up" if d.y < -4 else ""),
			])
			if d.length() < 12.0:
				_note("5. reached herb    top_left=%s" % p)
				_advance("04_xianxia_herb")
			else:
				_timed_out("walking to the herb", 10.0)
		5:
			if main.inventory.total("xianxia_gate:spirit_herb") < 1:
				failures.append("walked over the herb but did not pick it up")
			# Back west through the return portal at x 32..80, y 216..264.
			var target := Vector2(56, 232)
			var d2 := target - p
			_hold([
				"move_right" if d2.x > 4 else ("move_left" if d2.x < -4 else ""),
				"move_down" if d2.y > 4 else ("move_up" if d2.y < -4 else ""),
			])
			if main.runtime.world_id == "pastoral_village":
				_note("6. returned        world=%s  top_left=%s" % [main.runtime.world_id, p])
				_advance("05_village_returned")
			else:
				_timed_out("walking back through the return portal", 12.0)
		6:
			# The milestone's claim, in the running game rather than in a headless assertion.
			var carried: int = main.inventory.total("xianxia_gate:spirit_herb")
			_note("7. in village       carrying %d x %s"
				% [carried, main.catalog.display_name("xianxia_gate:spirit_herb", "zh-CN")])
			if carried < 1:
				failures.append("the herb did not survive the walk back to the village")
			if not main.hud.is_inventory_open():
				failures.append("the inventory panel is not open")

			if not main.save_game():
				failures.append("save failed: %s" % main.saves.last_error)
			main.inventory.clear()
			_note("8. after clearing   carrying %d" % main.inventory.total("xianxia_gate:spirit_herb"))
			if not main.load_game():
				failures.append("load failed: %s" % main.saves.last_error)
			var restored: int = main.inventory.total("xianxia_gate:spirit_herb")
			_note("9. after reload     world=%s  carrying %d x %s"
				% [main.runtime.world_id, restored,
				   main.catalog.display_name("xianxia_gate:spirit_herb", "zh-CN")])
			if restored < 1:
				failures.append("the herb did not survive a save/load round trip")
			_advance("06_after_reload")
			return false
		7:
			var f := FileAccess.open("%s/walkthrough.txt" % shots, FileAccess.WRITE)
			if f != null:
				f.store_string("\n".join(log_lines) + "\n")
			if failures.is_empty():
				print("\nWALKTHROUGH OK")
			else:
				for x in failures:
					print("  FAIL %s" % x)
				print("\nWALKTHROUGH FAILED")
			return true
	return false
