class_name SearchScreen
extends PuzzleScreen
## T08 search scene (PZ-PIER-01, test-set PIER-01 + spec 5.2): close-up of the pier, list of silhouettes in
## a strip at the bottom (white outlines, filled with ink when found; on hard two targets are given by a
## description). Tap an object: a target is found; a look-alike gets a reaction by level (easy explains,
## normal "Not that", hard nothing). Tap a silhouette to pick it (optional) — then reactions follow it.
## Zones: data/puzzles/layouts.yaml (level designer). The scene is drawn by the engine as a placeholder
## until the real art arrives; the zones stay the same.

var found: Array = []
var selected := ""
var _layout: Dictionary
var _scene: Control
var _strip: Control
var _counter: Label
var _flash := {}                 # object id → time left of the "found" ink ring animation


func _build() -> void:
	_layout = Game.data.layout(pz)
	var saved: Variant = Game.state.puzzle_progress.get(pz, {}).get("found")
	found = Array(saved) if typeof(saved) == TYPE_ARRAY else []
	_card_bottom = -strip_h() - 10
	_card_at_top = true
	_scene = Control.new()
	_scene.anchor_right = 1.0; _scene.anchor_bottom = 1.0; _scene.offset_bottom = -strip_h()
	_scene.mouse_filter = Control.MOUSE_FILTER_STOP
	_scene.clip_contents = true
	_scene.draw.connect(_draw_scene)
	_scene.gui_input.connect(_scene_input)
	add_child(_scene)
	_strip = Control.new()
	_strip.anchor_top = 1.0; _strip.anchor_right = 1.0; _strip.anchor_bottom = 1.0
	_strip.offset_top = -strip_h(); _strip.offset_left = 0
	_strip.mouse_filter = Control.MOUSE_FILTER_STOP
	_strip.draw.connect(_draw_strip)
	_strip.gui_input.connect(_strip_input)
	add_child(_strip)
	_counter = UiKit.label("", UiKit.FONT_SUB, UiKit.LAMP)
	_counter.anchor_left = 1.0; _counter.anchor_right = 1.0
	_counter.offset_left = -340; _counter.offset_right = -40; _counter.offset_top = 20
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_counter.add_theme_color_override("font_outline_color", UiKit.INK)
	_counter.add_theme_constant_override("outline_size", 8)
	add_child(_counter)
	_update_counter()


func _save_progress() -> void:
	Game.state.puzzle_progress[pz] = {"found": found}


func strip_h() -> float:
	return float(_layout.get("scene", {}).get("strip_px", 170))


func _process(delta: float) -> void:
	if _flash.is_empty():
		return
	for k in _flash.keys():
		_flash[k] = float(_flash[k]) - delta
		if _flash[k] <= 0.0:
			_flash.erase(k)
	_scene.queue_redraw()


func _update_counter() -> void:
	_counter.visible = SearchLogic.shows_counter(_v)
	_counter.text = Game.t("pz.pier01.counter", {"n": found.size(), "m": SearchLogic.targets(_v).size()})


# ------------------------------------------------------------ input

func _scene_input(ev: InputEvent) -> void:
	if _done or not (ev is InputEventScreenTouch) or not ev.pressed:
		return
	accept_event()
	tap_at(Vector2(ev.position.x / _scene.size.x, ev.position.y / _scene.size.y))


## Tap at a point of the scene in fractions (also used by the smoke test).
func tap_at(p: Vector2) -> Dictionary:
	var obj := SearchLogic.hit(_layout, level(), p)
	var res := SearchLogic.tap(obj, found, _v, selected)
	match res["kind"]:
		"found":
			found.append(res["target"])
			_flash[str(obj.get("id", ""))] = 0.8
			if selected == res["target"]:
				selected = ""
			hide_card()
			_update_counter()
			_strip.queue_redraw()
			_scene.queue_redraw()
			if SearchLogic.is_complete(found, _v):
				finish()
		"reaction":
			wrong(res["rule"])
		_:
			hide_card()
	return res


func _slot_rect(i: int, n: int) -> Rect2:
	var x0 := 270.0
	var w := (_strip.size.x - x0 - 24.0) / maxf(1.0, n)
	return Rect2(Vector2(x0 + w * i + 6, 10), Vector2(w - 12, strip_h() - 20))


func _strip_input(ev: InputEvent) -> void:
	if _done or not (ev is InputEventScreenTouch) or not ev.pressed:
		return
	var tg := SearchLogic.targets(_v)
	for i in tg.size():
		if _slot_rect(i, tg.size()).has_point(ev.position) and not (tg[i] in found):
			selected = "" if selected == tg[i] else str(tg[i])
			_strip.queue_redraw()
			accept_event()
			return


# ------------------------------------------------------------ drawing: list

func _draw_strip() -> void:
	var r := Rect2(Vector2.ZERO, _strip.size)
	_strip.draw_rect(r, UiKit.LAKE_DUSK)
	_strip.draw_line(Vector2(0, 0), Vector2(r.size.x, 0), UiKit.BRASS, 3.0)
	var tg := SearchLogic.targets(_v)
	var font := ThemeDB.fallback_font
	for i in tg.size():
		var s := _slot_rect(i, tg.size())
		var is_found: bool = tg[i] in found
		_strip.draw_rect(s, Color(UiKit.IVORY, 0.92) if is_found else Color(UiKit.INK, 0.6))
		_strip.draw_rect(s, UiKit.LAMP if selected == tg[i] else Color(UiKit.BRASS, 0.7), false, 5.0 if selected == tg[i] else 2.0)
		if SearchLogic.list_kind(tg[i], _v) == "description":
			var col := UiKit.INK if is_found else UiKit.IVORY
			var txt := Game.t("pz.pier01.desc." + str(tg[i]))
			var fs := UiKit.fit_font_size(txt, s.size.x - 20, s.size.y - 16, 24, 14, font)
			var th := font.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, s.size.x - 20, fs).y
			var top := s.position.y + maxf(8.0, (s.size.y - th) * 0.5) + font.get_ascent(fs)
			_strip.draw_multiline_string(font, Vector2(s.position.x + 10, top), txt, HORIZONTAL_ALIGNMENT_CENTER, s.size.x - 20, fs, -1, col)
		else:
			Silhouettes.draw(_strip, str(tg[i]), s.grow(-14), UiKit.INK if is_found else UiKit.IVORY, is_found)


# ------------------------------------------------------------ drawing: scene (placeholder art + found marks)

func _px(o: Dictionary) -> Rect2:
	var r: Array = o["rect"]
	var sz := _scene.size
	return Rect2(float(r[0]) * sz.x, float(r[1]) * sz.y, float(r[2]) * sz.x, float(r[3]) * sz.y)


func _draw_scene() -> void:
	var sz := _scene.size
	# lake in the fog, the pier deck (dark, wet)
	_scene.draw_rect(Rect2(Vector2.ZERO, sz), Color("#56676c"))
	_scene.draw_rect(Rect2(Vector2(0, sz.y * 0.0), Vector2(sz.x, sz.y * 0.22)), Color("#7d8c8e"))
	var deck := PackedVector2Array([Vector2(sz.x * 0.10, sz.y * 0.55), Vector2(sz.x, sz.y * 0.52), Vector2(sz.x, sz.y), Vector2(0, sz.y)])
	_scene.draw_colored_polygon(deck, Color("#3b3027"))
	for k in 9:
		var y := sz.y * (0.56 + k * 0.05)
		_scene.draw_line(Vector2(0, y), Vector2(sz.x, y - 6), Color("#2a221b"), 3.0)
	_scene.draw_line(Vector2(sz.x * 0.10, sz.y * 0.40), Vector2(sz.x, sz.y * 0.36), Color("#2a221b"), 6.0)   # railing
	for o in SearchLogic.objects(_layout, level()):
		if o.get("background", false):
			continue
		_draw_object(str(o.get("shape", "")), _px(o))
	# found: Clara's ink ring around the object
	for o in SearchLogic.objects(_layout, level()):
		var tg := str(o.get("target", ""))
		if tg == "" or not (tg in found) or not (tg in SearchLogic.targets(_v)):
			continue
		var r := _px(o)
		var a := 1.0
		if _flash.has(o["id"]):
			a = 1.0 - float(_flash[o["id"]]) * 0.5
		_ellipse(r.get_center(), r.size * 0.56, Color(UiKit.LAMP, a), 4.0)
	# fog layer
	_scene.draw_rect(Rect2(Vector2.ZERO, Vector2(sz.x, sz.y * 0.3)), Color(0.85, 0.88, 0.9, 0.12))


func _ellipse(c: Vector2, half: Vector2, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(c + Vector2(cos(a) * half.x, sin(a) * half.y))
	_scene.draw_polyline(pts, col, w)


func _draw_object(shape: String, r: Rect2) -> void:
	var c := r.get_center()
	var ci := _scene
	match shape:
		"boathouse":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.25), r.size * Vector2(1, 0.75)), Color("#4a3a2c"))
			ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(-10, r.size.y * 0.27), Vector2(c.x, r.position.y), r.position + Vector2(r.size.x + 10, r.size.y * 0.27)]), Color("#2f2620"))
			ci.draw_rect(Rect2(Vector2(c.x - r.size.x * 0.18, r.position.y + r.size.y * 0.5), Vector2(r.size.x * 0.36, r.size.y * 0.5)), Color("#2a1f18"))
			ci.draw_circle(Vector2(c.x + r.size.x * 0.12, r.position.y + r.size.y * 0.72), 7, UiKit.BRASS)   # padlock
			ci.draw_line(r.position + Vector2(r.size.x, r.size.y * 0.3), r.position + Vector2(r.size.x + 24, r.size.y * 0.75), Color("#777"), 5.0)   # gutter
		"oilskin":
			ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.3, 0), r.position + Vector2(r.size.x * 0.7, 0), r.end, r.position + Vector2(0, r.size.y)]), Color("#b89a3a"))
		"bucket":
			var top := r.size.y * 0.28
			ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, top), r.position + Vector2(r.size.x, top), r.end - Vector2(r.size.x * 0.12, 0), Vector2(r.position.x + r.size.x * 0.12, r.end.y)]), Color("#9aa3a6"))
			_wavy(Vector2(r.position.x + 4, r.position.y + top + 6), r.size.x - 8, Color("#d8ecf4"))
		"post":
			ci.draw_rect(r, Color("#2b241f"))
			if r.position.y < 20:
				ci.draw_rect(Rect2(r.position + Vector2(-6, -4), Vector2(r.size.x + 12, 22)), Color("#d9d6c4", 0.7))
		"ring":
			var rr := minf(r.size.x, r.size.y) * 0.45
			ci.draw_arc(c, rr * 0.72, 0, TAU, 32, Color("#e8e3d6"), rr * 0.5)
			for k in 4:
				var a := TAU * k / 4.0 + 0.4
				ci.draw_arc(c, rr * 0.72, a, a + 0.5, 6, Color("#c0442e"), rr * 0.5)
		"coil":
			for k in 4:
				ci.draw_arc(c, minf(r.size.x, r.size.y) * (0.15 + 0.1 * k), 0, TAU, 24, Color("#7b6544"), 6.0)
		"tarp_box":
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.3), r.size * Vector2(1, 0.7)), Color("#5b4a35"))
			ci.draw_rect(Rect2(r.position + Vector2(-6, r.size.y * 0.15), Vector2(r.size.x + 12, r.size.y * 0.45)), Color("#1f2a24"))
		"souwester":
			ci.draw_circle(c, r.size.y * 0.35, Color("#c8a43a"))
			ci.draw_arc(c + Vector2(0, r.size.y * 0.1), r.size.x * 0.48, 0.2, PI - 0.2, 12, Color("#c8a43a"), 8.0)
		"rod":
			ci.draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x + 30, r.position.y), Color("#8a6a3e"), 4.0)
			ci.draw_circle(Vector2(r.position.x + 6, r.end.y - 30), 8, Color("#555"))
		"puddle":
			var pts := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				pts.append(c + Vector2(cos(a) * r.size.x * (0.42 + 0.05 * sin(a * 3.0)), sin(a) * r.size.y * 0.22))
			ci.draw_colored_polygon(pts, Color("#8fa9b6"))
			ci.draw_line(c + Vector2(-r.size.x * 0.15, -4), c + Vector2(r.size.x * 0.1, -8), Color(1, 1, 1, 0.8), 4.0)
		"leaf":
			Silhouettes.leaf(ci, c, minf(r.size.x, r.size.y) * 0.36, Color("#b5482a") if int(c.x) % 2 == 0 else Color("#c9a02f"), true)
		"hat":
			ci.draw_circle(c + Vector2(0, r.size.y * 0.12), r.size.x * 0.46, Color("#4b4038"))
			ci.draw_circle(c + Vector2(0, r.size.y * 0.05), r.size.x * 0.24, Color("#5a4c42"))
			ci.draw_arc(c + Vector2(0, r.size.y * 0.05), r.size.x * 0.26, 0, TAU, 24, Color("#2a201a"), 5.0)
		"coat":
			ci.draw_rect(r, Color("#5c6266"))
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.45), Vector2(r.size.x, 10)), Color("#43494c"))   # belt
			for k in 14:
				var x := r.position.x + 8 + k * (r.size.x - 16) / 13.0
				ci.draw_line(Vector2(x, r.position.y + 6), Vector2(x + 3, r.position.y + 14), Color("#9aa2a6"), 2.0)   # nap
		"hem":
			var band := Rect2(r.position, Vector2(r.size.x, r.size.y * 0.38))
			ci.draw_rect(band, Color("#3a3f42"))
			var pts2 := PackedVector2Array()
			for i in 13:
				pts2.append(Vector2(band.position.x + band.size.x * i / 12.0, band.position.y + 3 + (i % 3) * 4))
			ci.draw_polyline(pts2, Color("#2c3134"), 3.0)
		"gull":
			ci.draw_circle(c, r.size.y * 0.3, Color("#eeeeea"))
			ci.draw_line(c, c + Vector2(r.size.x * 0.45, -r.size.y * 0.2), Color("#eeeeea"), 8.0)
		"feather":
			var a2 := c - Vector2(r.size.x * 0.4, -r.size.y * 0.1)
			var b2 := c + Vector2(r.size.x * 0.4, -r.size.y * 0.1)
			ci.draw_line(a2, b2, Color("#c9c9c4"), r.size.y * 0.16)
			ci.draw_line(a2, b2, Color("#777"), 2.0)


func _wavy(p: Vector2, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		pts.append(p + Vector2(w * i / 12.0, sin(i * 1.4) * 3.0))
	_scene.draw_polyline(pts, col, 3.0)
