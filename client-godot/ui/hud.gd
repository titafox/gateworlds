extends CanvasLayer
## What the player can see.
##
## Three things, in order of how often they matter: what you are carrying, what just
## happened, and where you are. Nothing is placed in the middle of the screen -- the world is
## the content, and an interface that covers it is an interface that has forgotten what the
## game is for.

const HudTheme := preload("res://ui/hud_theme.gd")

var _font: Font
var _panel := Color("#101318")
var _text := HudTheme.PAPER
var _dim := HudTheme.DIM_ON_DARK
## Hints are drawn straight onto the world, not onto a panel, so their contrast has to come
## from the world. Taking it from the panel works on the two worlds shipped today and
## vanishes on the first pale one somebody contributes.
var _hint := HudTheme.DIM_ON_DARK

var _world_name := ""
var _rows: Array = []          # [{ icon: Color, name: String, origin: String, count: int }]
var _inventory_open := false

var _notice := ""
var _notice_life := 0.0
const NOTICE_SECONDS := 2.6

var _canvas: Control


func _init() -> void:
	layer = 10
	_font = HudTheme.font()
	_canvas = Control.new()
	_canvas.name = "HudCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


func set_world(display_name: String, background: Color) -> void:
	_world_name = display_name
	_panel = HudTheme.panel_for(background)
	_text = HudTheme.text_on(_panel)
	_dim = HudTheme.dim_on(_panel)
	_hint = HudTheme.dim_on(background)
	_canvas.queue_redraw()


func set_rows(rows: Array) -> void:
	_rows = rows
	_canvas.queue_redraw()


func toggle_inventory() -> void:
	_inventory_open = not _inventory_open
	_canvas.queue_redraw()


func is_inventory_open() -> bool:
	return _inventory_open


## Says what changed, in the same words as the action that changed it.
func show_notice(text: String) -> void:
	_notice = text
	_notice_life = NOTICE_SECONDS
	_canvas.queue_redraw()


func _process(delta: float) -> void:
	if _notice_life <= 0.0:
		return
	_notice_life -= delta
	if _notice_life <= 0.0:
		_notice = ""
	_canvas.queue_redraw()


# ------------------------------------------------------------------------------ drawing

func _draw_hud() -> void:
	var view: Vector2 = _canvas.size
	_draw_world_name()
	if _inventory_open:
		_draw_inventory()
	_draw_hints(view)
	_draw_notice(view)


func _draw_world_name() -> void:
	if _world_name.is_empty():
		return
	var w := _measure(_world_name, HudTheme.SIZE_WORLD) + HudTheme.PAD * 2
	_canvas.draw_rect(Rect2(0, 0, w, 24), _panel)
	_canvas.draw_string(_font, Vector2(HudTheme.PAD, 16), _world_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_WORLD, _text)


func _draw_inventory() -> void:
	var top := 32.0
	var rows: int = maxi(_rows.size(), 1)
	var height := HudTheme.PAD * 2 + rows * HudTheme.ROW_HEIGHT
	_canvas.draw_rect(Rect2(0, top, HudTheme.PANEL_WIDTH, height), _panel)

	if _rows.is_empty():
		# An empty panel is an invitation to act, not a statement of fact.
		_canvas.draw_string(_font, Vector2(HudTheme.PAD, top + HudTheme.PAD + 13),
			"Nothing yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_ITEM, _text)
		_canvas.draw_string(_font, Vector2(HudTheme.PAD, top + HudTheme.PAD + 25),
			"Walk over things.", HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_META, _dim)
		return

	var y := top + HudTheme.PAD
	for row in _rows:
		# The icon is the item's own colour -- the same rectangle the world draws it as. The
		# inventory is made of the same atoms as the place the item came from.
		_canvas.draw_rect(
			Rect2(HudTheme.PAD, y + 5, HudTheme.ICON, HudTheme.ICON), row["icon"])

		var count := "%d" % row["count"]
		var count_w := _measure(count, HudTheme.SIZE_ITEM)
		var name_x := HudTheme.PAD * 2 + HudTheme.ICON
		var name_w := HudTheme.PANEL_WIDTH - name_x - count_w - HudTheme.PAD * 1.5

		_canvas.draw_string(_font, Vector2(name_x, y + 15), row["name"],
			HORIZONTAL_ALIGNMENT_LEFT, name_w, HudTheme.SIZE_ITEM, _text)
		_canvas.draw_string(_font,
			Vector2(HudTheme.PANEL_WIDTH - HudTheme.PAD - count_w, y + 15), count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_ITEM, _text)

		# Where a thing came from is the interesting fact about it here. It is also the only
		# place a player ever sees that item ids carry the world that defined them.
		_canvas.draw_string(_font, Vector2(name_x, y + 25), row["origin"],
			HORIZONTAL_ALIGNMENT_LEFT, name_w + count_w, HudTheme.SIZE_META, _dim)
		y += HudTheme.ROW_HEIGHT


func _draw_hints(view: Vector2) -> void:
	var hint := "I  inventory     F5  save     F9  load"
	_canvas.draw_string(_font, Vector2(HudTheme.PAD, view.y - HudTheme.PAD), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_META, _hint)


## The one piece of motion in the game, and it answers something the player did.
func _draw_notice(view: Vector2) -> void:
	if _notice.is_empty():
		return
	var fade: float = clampf(_notice_life / 0.6, 0.0, 1.0)
	var w := _measure(_notice, HudTheme.SIZE_ITEM) + HudTheme.PAD * 3
	var x := (view.x - w) * 0.5
	var y := view.y - 56.0

	var bar := HudTheme.SIGNAL
	bar.a = fade
	_canvas.draw_rect(Rect2(x, y, w, 22), bar)

	var on_signal := HudTheme.text_on(HudTheme.SIGNAL)
	on_signal.a = fade
	_canvas.draw_string(_font, Vector2(x + HudTheme.PAD * 1.5, y + 15), _notice,
		HORIZONTAL_ALIGNMENT_LEFT, -1, HudTheme.SIZE_ITEM, on_signal)


func _measure(text: String, size: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
