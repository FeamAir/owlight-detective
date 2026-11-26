class_name CloseupScreen
extends Overlay
## Close-up of an object (дизайн 3.6). Background = art (placeholder now); puzzle-relevant details
## (signs, water levels, scale numbers, tape marks) are a separate engine layer driven by values/<profile>.yaml,
## so the real backgrounds can arrive later without touching this logic (brief №18).

signal open_puzzle(pz: String)

var asset := ""
var puzzle := ""
var _layer: Control
var _bowl_zoom := ""          # sign of the zoomed bowl ("" = overview, "birdbath" on hard)


func setup(asset_name: String, puzzle_id: String = "") -> CloseupScreen:
	asset = asset_name
	puzzle = puzzle_id
	return self


func _ready() -> void:
	var bg := TextureRect.new()
	UiKit.full_rect(bg)
	bg.texture = Game.data.texture("cu", asset)
	if bg.texture == null:
		bg.texture = Game.data.texture("cu", "cu_generic")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_layer = Control.new()
	UiKit.full_rect(_layer)
	_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_layer.draw.connect(_draw_layer)
	_layer.gui_input.connect(_layer_input)
	add_child(_layer)
	match asset:
		"cu_gate_pillars":
			add_title(Game.t("cu.pillars.title"))
		"cu_alley_fountain":
			add_title(Game.t("cu.fountain.title"))
	add_back_button()
	if puzzle != "":
		var b := UiKit.button("› " + Game.t("cu.open_puzzle"), 420, true)
		b.anchor_left = 1.0; b.anchor_right = 1.0; b.anchor_top = 1.0; b.anchor_bottom = 1.0
		b.offset_left = -460; b.offset_right = -24; b.offset_top = -24 - UiKit.BIG_TAP; b.offset_bottom = -24
		b.pressed.connect(func() -> void: open_puzzle.emit(puzzle))
		add_child(b)


func on_back() -> bool:
	if _bowl_zoom != "":
		_bowl_zoom = ""
		_layer.queue_redraw()
		return true
	return super.on_back()


# ------------------------------------------------------------ detail layer

func _v() -> Dictionary:
	return Game.data.values("PZ-GATE-01", Game.state.difficulty)


func _bowl_positions() -> Dictionary:
	# top-down: alley side at the bottom; bowls clockwise from the alley side (test-set GATE-01)
	var order: Array = _v().get("fountain_order", ["gear", "owl", "moon", "key"])
	var c := size * Vector2(0.5, 0.5)
	var out := {}
	for i in order.size():
		var a := PI / 2 + TAU * i / order.size()       # start at bottom, clockwise on screen
		out[order[i]] = c + Vector2(cos(a), sin(a)) * Vector2(250, 185)
	return out


func _layer_input(ev: InputEvent) -> void:
	if asset != "cu_alley_fountain" or not (ev is InputEventScreenTouch) or not ev.pressed:
		return
	if _bowl_zoom != "":
		_bowl_zoom = ""
		_layer.queue_redraw()
		return
	var pos: Vector2 = ev.position
	for s in _bowl_positions():
		if pos.distance_to(_bowl_positions()[s]) < 110:
			_bowl_zoom = s
			_layer.queue_redraw()
			return
	var v := _v()
	if v.has("decoys") and pos.distance_to(size * Vector2(0.86, 0.8)) < 80:
		_bowl_zoom = "birdbath"
		_layer.queue_redraw()


func _draw_layer() -> void:
	match asset:
		"cu_gate_pillars":
			_draw_pillars()
		"cu_alley_fountain":
			if _bowl_zoom == "":
				_draw_fountain()
			else:
				_draw_bowl_zoom()
		"cu_gate_recorder":
			_draw_gate_tape()


func _draw_pillars() -> void:
	var pillars: Array = _v().get("pillars", [])
	var n := 4
	for i in n:
		var x := size.x * (0.2 + 0.2 * i)
		var top := size.y * 0.25
		_layer.draw_rect(Rect2(Vector2(x - 70, top), Vector2(140, size.y * 0.62)), Color(0.48, 0.46, 0.42))
		_layer.draw_rect(Rect2(Vector2(x - 70, top), Vector2(140, size.y * 0.62)), UiKit.INK, false, 4.0)
		var c := Vector2(x, top + 110)
		_layer.draw_circle(c, 64, UiKit.BRASS.darkened(0.4))
		var sign_id: String = pillars[i] if i < pillars.size() else "lantern"
		SignDraw.draw(_layer, sign_id, c, 58, UiKit.IVORY, Color(0.18, 0.18, 0.18))


func _draw_fountain() -> void:
	var v := _v()
	var c := size * Vector2(0.5, 0.5)
	_layer.draw_circle(c, 300, Color(0.35, 0.42, 0.46, 0.85))
	_layer.draw_arc(c, 300, 0, TAU, 64, UiKit.INK, 6.0)
	_layer.draw_circle(c, 60, Color(0.6, 0.6, 0.56))                 # owl on the plinth
	SignDraw.draw(_layer, "owl", c, 50, UiKit.INK, Color(0.6, 0.6, 0.56))
	var font := ThemeDB.fallback_font
	if v.has("decoys"):
		var year := str(v["decoys"].get("plinth_year", ""))
		_layer.draw_string(font, c + Vector2(-50, 100), year, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiKit.IVORY)
		var bb := size * Vector2(0.86, 0.8)
		_layer.draw_circle(bb, 46, Color(0.55, 0.55, 0.5))
		_layer.draw_arc(bb, 46, 0, TAU, 32, UiKit.INK, 4.0)
	for s in _bowl_positions():
		var p: Vector2 = _bowl_positions()[s]
		_layer.draw_circle(p, 84, Color(0.55, 0.55, 0.5))
		_layer.draw_circle(p, 60, Color(0.3, 0.45, 0.55))
		_layer.draw_arc(p, 84, 0, TAU, 48, UiKit.INK, 4.0)
		SignDraw.draw(_layer, s, p + Vector2(0, -56), 28, UiKit.INK, Color(0.75, 0.73, 0.66))
	_layer.draw_string(font, Vector2(40, size.y - 160), Game.t("cu.tap_bowl"), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, UiKit.LAMP)
	_layer.draw_string(font, Vector2(size.x * 0.5 - 60, size.y - 24), "↓ аллея / drive", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.FOG)


func _draw_bowl_zoom() -> void:
	var v := _v()
	var levels: Dictionary = v.get("levels", {})
	var numbered: bool = v.get("numbered", true)
	var level := 0
	var sign_id := _bowl_zoom
	if _bowl_zoom == "birdbath":
		level = int(v.get("decoys", {}).get("birdbath_level", 0))
		sign_id = ""
	else:
		level = int(levels.get(_bowl_zoom, 0))
	_layer.draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.55))
	var box := Rect2(size.x * 0.5 - 220, size.y * 0.12, 440, size.y * 0.72)
	_layer.draw_rect(box, Color(0.62, 0.6, 0.55))
	_layer.draw_rect(box, UiKit.INK, false, 5.0)
	var inner := box.grow(-40)
	var font := ThemeDB.fallback_font
	var step := inner.size.y / 10.0
	var water_y := inner.end.y - step * level
	_layer.draw_rect(Rect2(Vector2(inner.position.x, water_y), Vector2(inner.size.x, inner.end.y - water_y)), Color(0.3, 0.5, 0.62, 0.9))
	_layer.draw_line(Vector2(inner.position.x, water_y), Vector2(inner.end.x, water_y), Color(0.85, 0.95, 1.0), 4.0)
	for k in range(1, 10):
		var y := inner.end.y - step * k
		_layer.draw_line(Vector2(inner.position.x, y), Vector2(inner.position.x + 60, y), UiKit.INK, 4.0)
		if numbered:
			_layer.draw_string(font, Vector2(inner.position.x + 72, y + 10), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, UiKit.INK)
	# drain hole at the water level (сливное отверстие)
	_layer.draw_circle(Vector2(inner.end.x - 30, water_y), 10, UiKit.INK)
	if sign_id != "":
		SignDraw.draw(_layer, sign_id, Vector2(box.get_center().x, box.position.y - 2), 44, UiKit.IVORY, Color(0.3, 0.3, 0.3))


func _draw_gate_tape() -> void:
	var p := Game.data.values("SNAP-GATE-TAPE", Game.state.difficulty)
	var r := Rect2(size.x * 0.08, size.y * 0.42, size.x * 0.84, 140)
	_layer.draw_rect(r, UiKit.IVORY)
	_layer.draw_rect(r, UiKit.INK, false, 3.0)
	var font := ThemeDB.fallback_font
	# two days: 14 and 15 October, one pen mark per gate opening
	var days := [["14", p.get("marks_14", [])], ["15", p.get("marks_15", [])]]
	for di in 2:
		var x0 := r.position.x + r.size.x * 0.5 * di
		_layer.draw_line(Vector2(x0, r.position.y), Vector2(x0, r.end.y), UiKit.INK, 2.0)
		_layer.draw_string(font, Vector2(x0 + 8, r.position.y - 10), "%s окт. / %s Oct" % [days[di][0], days[di][0]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiKit.LAMP)
		for h in range(0, 24, 3):
			var xh := x0 + r.size.x * 0.5 * h / 24.0
			_layer.draw_string(font, Vector2(xh + 2, r.end.y + 28), str(h), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.IVORY)
		var marks: Variant = days[di][1]
		if typeof(marks) == TYPE_ARRAY:
			for m in marks:
				var hm := str(m).split(":")
				var t := (float(hm[0]) + float(hm[1]) / 60.0) / 24.0
				var xm := x0 + r.size.x * 0.5 * t
				_layer.draw_line(Vector2(xm, r.end.y - 20), Vector2(xm, r.position.y + 20), Color("#1d3a7a"), 4.0)
				_layer.draw_string(font, Vector2(xm - 34, r.position.y + 50), str(m), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiKit.INK)
