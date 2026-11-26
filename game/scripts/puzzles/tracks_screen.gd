class_name TracksScreen
extends PuzzleScreen
## T16 prints on the gravel (PZ-ALLEY-01, spec 5.3): top-forward view, the path goes up to the lake,
## the main drive with tyre ruts runs along the bottom. Tap a print to mark its whole chain or group
## (tap again to unmark); a marked chain gets a toggle "to the lake / to the drive". "Done" checks the
## marked groups and directions. The picture is drawn by the engine from the values (placeholder art).

var selected: Array = []
var dirs: Dictionary = {}
var _lay: Dictionary
var _view: Control
var _toggles := {}               # chain id → Button
var _task: Label


func _build() -> void:
	_lay = TracksLogic.layout(_v, level())
	var saved: Dictionary = Game.state.puzzle_progress.get(pz, {})
	selected = Array(saved.get("selected", []))
	dirs = Dictionary(saved.get("dirs", {}))
	_view = Control.new()
	UiKit.full_rect(_view)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.draw.connect(_draw_view)
	_view.gui_input.connect(_input_view)
	add_child(_view)
	_task = UiKit.label(Game.t("pz.alley01.task"), UiKit.FONT_UI, UiKit.IVORY)
	_task.add_theme_color_override("font_outline_color", UiKit.INK)
	_task.add_theme_constant_override("outline_size", 8)
	_task.offset_left = 28; _task.offset_top = 190; _task.offset_right = 470; _task.offset_bottom = 520
	add_child(_task)
	for cid in TracksLogic.chain_ids(_v):
		var b := UiKit.button("", 250)
		b.custom_minimum_size.y = UiKit.BIG_TAP
		b.pressed.connect(_toggle_dir.bind(cid))
		add_child(b)
		_toggles[cid] = b
	var done := add_action_button(Game.t("pz.done"), 280)
	done.pressed.connect(_check)
	get_viewport().size_changed.connect(_place_toggles)
	_place_toggles.call_deferred()


func _save_progress() -> void:
	Game.state.puzzle_progress[pz] = {"selected": selected, "dirs": dirs}


# ------------------------------------------------------------ design space ↔ screen

func _scale() -> float:
	var vs := get_viewport_rect().size
	return minf(vs.x / TracksLogic.W, vs.y / TracksLogic.H)


func _origin() -> Vector2:
	var vs := get_viewport_rect().size
	return (vs - Vector2(TracksLogic.W, TracksLogic.H) * _scale()) * 0.5


func to_screen(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


func to_design(p: Vector2) -> Vector2:
	return (p - _origin()) / _scale()


func _place_toggles() -> void:
	for cid in _toggles:
		var b: Button = _toggles[cid]
		var top := Vector2(800, 9999)
		var side := "left"
		for c in TracksLogic.chains(_v):
			if c["id"] == cid:
				side = str(c.get("side", "left"))
		for pr in _lay["prints"]:
			if pr["group"] == cid and (pr["pos"] as Vector2).y < top.y:
				top = pr["pos"]
		var anchor := to_screen(top)
		var x := anchor.x - 250 - 70 if side == "left" else anchor.x + 70
		b.position = Vector2(x, maxf(8.0, anchor.y - UiKit.BIG_TAP * 0.5))
		b.size = Vector2(250, UiKit.BIG_TAP)
		b.visible = cid in selected and not _done
		var d := str(dirs.get(cid, ""))
		b.text = Game.t("pz.alley01." + d) if d != "" else Game.t("pz.alley01.dir_unset")


# ------------------------------------------------------------ input

func _input_view(ev: InputEvent) -> void:
	if _done or not (ev is InputEventScreenTouch) or not ev.pressed:
		return
	accept_event()
	tap_design(to_design(ev.position))


## Tap at a design-space point (also used by the smoke test). Returns the group tapped.
func tap_design(p: Vector2) -> String:
	var g := TracksLogic.hit(_lay, p)
	if g == "":
		return ""
	if g in selected:
		selected.erase(g)
	else:
		selected.append(g)
	hide_card()
	_place_toggles()
	_view.queue_redraw()
	return g


func _toggle_dir(cid: String) -> void:
	if _done:
		return
	dirs[cid] = TracksLogic.next_dir(str(dirs.get(cid, "")))
	_place_toggles()
	_view.queue_redraw()


func _check() -> void:
	if _done:
		return
	var r := TracksLogic.check(selected, dirs, _v)
	if r["ok"]:
		finish()
		_place_toggles()
		_view.queue_redraw()
		return
	wrong(r["rule"], r["n"], r["m"])


# ------------------------------------------------------------ drawing

func _draw_view() -> void:
	var vs := get_viewport_rect().size
	_view.draw_rect(Rect2(Vector2.ZERO, vs), Color("#3f4a3a"))           # grass
	var s := _scale()
	var path := Rect2(to_screen(Vector2(TracksLogic.PATH_X.x, 0)), Vector2(TracksLogic.PATH_X.y - TracksLogic.PATH_X.x, 600) * s)
	_view.draw_rect(path, Color("#4b4844"))                               # wet gravel path
	var drive := Rect2(to_screen(Vector2(0, 598)), Vector2(TracksLogic.W, 122) * s)
	_view.draw_rect(drive, Color("#4b4844"))
	_gravel_dots(path)
	_gravel_dots(drive)
	var font := ThemeDB.fallback_font
	_view.draw_string(font, to_screen(Vector2(760, 30)), Game.t("pz.alley01.lake"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), UiKit.FOG)
	_view.draw_string(font, to_screen(Vector2(1120, 594)), Game.t("pz.alley01.drive"), HORIZONTAL_ALIGNMENT_LEFT, -1, int(24 * s), UiKit.FOG)
	# tyre ruts: sharp edges, light ridges of pressed gravel, no water (the calibration sample)
	for y in [626.0, 672.0]:
		var a := to_screen(Vector2(0, y))
		var b := to_screen(Vector2(TracksLogic.W, y))
		_view.draw_line(a, b, Color("#2a2725"), 22 * s)
		_view.draw_line(a - Vector2(0, 13 * s), b - Vector2(0, 13 * s), Color("#8a857c"), 3 * s)
		_view.draw_line(a + Vector2(0, 13 * s), b + Vector2(0, 13 * s), Color("#8a857c"), 3 * s)
	# trampled near the drive: overlapping partial prints, none whole
	var tr: Rect2 = _lay["trampled"]
	for k in 26:
		var p := tr.position + Vector2(fposmod(k * 137.0, tr.size.x), fposmod(k * 53.0, tr.size.y))
		_view.draw_circle(to_screen(p), (14 + (k % 4) * 4) * s, Color("#34312e", 0.9))
		_view.draw_arc(to_screen(p), (16 + (k % 4) * 4) * s, k, k + 2.0, 6, Color("#77726a"), 2 * s)
	# washed pits: soft round dents with water, slumped edges, no ridges
	for pt in _lay["pits"]:
		var c := to_screen(pt["pos"])
		_view.draw_circle(c, (pt["r"] + 6) * s, Color("#3e3b38"))
		_view.draw_circle(c, pt["r"] * s, Color("#5f7884"))
		_view.draw_line(c + Vector2(-8, -6) * s, c + Vector2(6, -10) * s, Color("#c9dbe3", 0.7), 3 * s)
	# fresh prints
	for pr in _lay["prints"]:
		_draw_print(pr, s)
	# gull tracks (hard): three toes
	for g in _lay["gull"]:
		var c2 := to_screen(g["pos"])
		for a2 in [-0.5, 0.0, 0.5]:
			var d := Vector2(sin(g["rot"] + a2), -cos(g["rot"] + a2)) * 26 * s
			_view.draw_line(c2, c2 + d, Color("#25221f"), 5 * s)
	# fog layer (hard)
	if _v.get("fog_layer", false):
		_view.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.86, 0.88, 0.9, 0.16))
	# selection: Clara's ink
	for g2 in selected:
		_draw_selection(str(g2), s)


func _gravel_dots(r: Rect2) -> void:
	var n := int(r.size.x * r.size.y / 900.0)
	for k in mini(n, 900):
		var p := r.position + Vector2(fposmod(k * 97.31, r.size.x), fposmod(k * 41.77, r.size.y))
		_view.draw_rect(Rect2(p, Vector2(3, 3)), Color("#5d5953"))


func _draw_print(pr: Dictionary, s: float) -> void:
	var c := to_screen(pr["pos"])
	var l: float = float(pr["len"]) * s
	var dir := float(pr["dir"])
	var toe := c + Vector2(0, -0.2 * l * dir)
	var heel := c + Vector2(0, 0.3 * l * dir)
	# ridges of pressed gravel (light), then the sharp dark print
	_oval(toe, Vector2(0.24, 0.27) * l + Vector2(5, 5) * s, Color("#8f8a80"))
	_oval(toe, Vector2(0.21, 0.24) * l, Color("#1f1c1a"))
	if not pr["toe_only"]:
		_oval(heel, Vector2(0.15, 0.17) * l + Vector2(5, 5) * s, Color("#8f8a80"))
		_oval(heel, Vector2(0.13, 0.15) * l, Color("#121010"))       # heel deeper → darker
		_view.draw_line(toe + Vector2(0, 0.2 * l * dir), heel - Vector2(0, 0.12 * l * dir), Color("#1f1c1a"), 0.16 * l)


func _oval(c: Vector2, half: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y))
	_view.draw_colored_polygon(pts, col)


func _draw_selection(g: String, s: float) -> void:
	var ink := Color(UiKit.LAMP, 0.95)
	var pts := PackedVector2Array()
	for pr in _lay["prints"]:
		if pr["group"] == g:
			var c := to_screen(pr["pos"])
			_view.draw_arc(c, float(pr["len"]) * 0.5 * s, 0, TAU, 28, ink, 3.0)
			pts.append(c)
	if pts.size() > 1:
		_view.draw_polyline(pts, Color(ink, 0.5), 2.0)
	match g:
		"pits":
			for pt in _lay["pits"]:
				_view.draw_arc(to_screen(pt["pos"]), (pt["r"] + 12) * s, 0, TAU, 24, ink, 3.0)
		"gull":
			for gg in _lay["gull"]:
				_view.draw_arc(to_screen(gg["pos"]), 34 * s, 0, TAU, 24, ink, 3.0)
		"trampled":
			var r: Rect2 = _lay["trampled"]
			_view.draw_rect(Rect2(to_screen(r.position), r.size * s), ink, false, 3.0)
		"ruts":
			var r2: Rect2 = _lay["ruts"]
			_view.draw_rect(Rect2(to_screen(r2.position), r2.size * s), ink, false, 3.0)
