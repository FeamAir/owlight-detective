class_name CompareScreen
extends PuzzleScreen
## T15 "compare" mode (PZ-GATE-02, spec 5.4): the weather tape on top (scrolls sideways; dates at every
## midnight, hour labels by level), below it the notes from the pier and — as tabs — the weather log and,
## on hard, the gate tape. Tap a fragment to mark it with the pen (two at most), pick one of four
## conclusions, "Done" checks. A mistake costs nothing: selection resets on normal / hard, on easy the
## right parts stay marked. The tape is drawn by the engine from the values (placeholder art).

const PX_PER_H := 72.0
const TAPE_H := 196.0
const TAPE_PAD := 60.0

var selected: Array = []
var conclusion := ""
var _zones: Array = []
var _snap_v: Dictionary
var _tape_scroll: ScrollContainer
var _tape: Control
var _tab_row: HBoxContainer
var _rows: VBoxContainer
var _doc := "notes"
var _frag_buttons := {}
var _concl_buttons := {}
var _picked: Label
var _done_btn: Button
var _t0 := 0.0
var _t1 := 0.0
var _tabs := {}
var _press_x := -1.0


func _build() -> void:
	_snap_v = Game.data.values("SNAP-GATE-TAPE", level())
	_zones = CompareLogic.tape_zones(_v)
	var tape: Dictionary = _v.get("tape", {})
	_t0 = CompareLogic.tape_hour(str(tape.get("from", "14 Oct 00:00")))
	_t1 = CompareLogic.tape_hour(str(tape.get("to", "15 Oct 10:00")))
	var saved: Dictionary = Game.state.puzzle_progress.get(pz, {})
	selected = Array(saved.get("selected", []))
	conclusion = str(saved.get("conclusion", ""))
	add_child(UiKit.dim_layer(0.9))
	# --- the tape
	var tape_title := UiKit.label(Game.t("pz.gate02.doc.tape"), UiKit.FONT_UI - 4, UiKit.LAMP)
	tape_title.offset_left = 28; tape_title.offset_top = 6; tape_title.offset_right = 900; tape_title.offset_bottom = 44
	add_child(tape_title)
	_tape_scroll = ScrollContainer.new()
	_tape_scroll.anchor_right = 1.0
	_tape_scroll.offset_left = 24; _tape_scroll.offset_right = -24; _tape_scroll.offset_top = 44; _tape_scroll.offset_bottom = 44 + TAPE_H + 16
	_tape_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_tape_scroll)
	_tape = Control.new()
	_tape.custom_minimum_size = Vector2((_t1 - _t0) * PX_PER_H + TAPE_PAD * 2.0, TAPE_H)
	_tape.mouse_filter = Control.MOUSE_FILTER_PASS
	_tape.draw.connect(_draw_tape)
	_tape.gui_input.connect(_tape_input)
	_tape_scroll.add_child(_tape)
	# --- documents (tabs) on the left
	var left := VBoxContainer.new()
	left.anchor_right = 0.5; left.anchor_bottom = 1.0
	left.offset_left = 24; left.offset_top = 44 + TAPE_H + 24; left.offset_bottom = -24 - UiKit.BIG_TAP - 12
	add_child(left)
	_tab_row = HBoxContainer.new()
	left.add_child(_tab_row)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	sc.add_child(_rows)
	for d in CompareLogic.docs(_v, _snap_v):
		if d == "tape":
			continue
		var tb := UiKit.button(Game.t("pz.gate02.doc." + d))
		tb.custom_minimum_size.y = 72
		tb.add_theme_font_size_override("font_size", UiKit.FONT_UI - 4)
		tb.pressed.connect(_show_doc.bind(d))
		_tab_row.add_child(tb)
		_tabs[d] = tb
	# --- conclusions on the right
	var right := VBoxContainer.new()
	right.anchor_left = 0.515; right.anchor_right = 1.0; right.anchor_bottom = 1.0
	right.offset_right = -24; right.offset_top = 44 + TAPE_H + 24; right.offset_bottom = -24 - UiKit.BIG_TAP - 12
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	for c in CompareLogic.conclusions(_v):
		var b := UiKit.button(Game.t("pz.gate02.concl." + c))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiKit.FONT_UI - 8)
		b.add_theme_stylebox_override("normal", _compact(UiKit.LAKE_DUSK.lerp(UiKit.INK, 0.3), UiKit.BRASS, 3))
		b.add_theme_stylebox_override("hover", _compact(UiKit.LAKE_DUSK.lerp(UiKit.BRASS, 0.25), UiKit.LAMP, 3))
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_conclusion.bind(c))
		right.add_child(b)
		_concl_buttons[c] = b
	_picked = UiKit.label("", UiKit.FONT_UI, UiKit.FOG)
	_picked.anchor_left = 1.0; _picked.anchor_right = 1.0; _picked.anchor_top = 1.0; _picked.anchor_bottom = 1.0
	_picked.offset_left = -640; _picked.offset_right = -330; _picked.offset_top = -24 - UiKit.BIG_TAP; _picked.offset_bottom = -24
	_picked.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_picked.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_picked)
	_done_btn = add_action_button(Game.t("pz.done"), 280)
	_done_btn.pressed.connect(_check)
	_show_doc("notes")
	_refresh()
	_scroll_to_end.call_deferred()


func _ready() -> void:
	super._ready()
	tutorial_once("UI-TUT-09")


func _scroll_to_end() -> void:
	_tape_scroll.scroll_horizontal = int(_tape.custom_minimum_size.x)


func _save_progress() -> void:
	Game.state.puzzle_progress[pz] = {"selected": selected, "conclusion": conclusion}


static func _compact(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var sb := UiKit._box(bg, border, bw, 8)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	return sb


# ------------------------------------------------------------ documents

func frag_text(id: String) -> String:
	if id.begins_with("gate_"):
		for m in CompareLogic.gate_marks(_snap_v):
			if m["id"] == id:
				return Game.t("pz.gate02.gate_mark", {"d": m["day"], "t": m["time"]})
	return Game.t("frag." + id)


func _show_doc(d: String) -> void:
	_doc = d
	for c in _rows.get_children():
		c.queue_free()
	_frag_buttons.clear()
	for f in CompareLogic.fragments(_v, _snap_v):
		if f["doc"] != d:
			continue
		var b := UiKit.button(frag_text(f["id"]))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", UiKit.FONT_UI - 6)
		b.add_theme_stylebox_override("normal", _compact(UiKit.LAKE_DUSK.lerp(UiKit.INK, 0.3), UiKit.BRASS, 2))
		b.add_theme_stylebox_override("hover", _compact(UiKit.LAKE_DUSK.lerp(UiKit.BRASS, 0.25), UiKit.LAMP, 2))
		b.custom_minimum_size.y = 72
		b.pressed.connect(toggle.bind(str(f["id"])))
		_rows.add_child(b)
		_frag_buttons[f["id"]] = b
	_refresh()


# ------------------------------------------------------------ selection

## Marks / unmarks a fragment (at most two). Also used by the smoke test.
func toggle(id: String) -> void:
	if _done:
		return
	if id in selected:
		selected.erase(id)
	elif selected.size() < 2:
		selected.append(id)
	hide_card()
	_refresh()


func _pick_conclusion(c: String) -> void:
	if _done:
		return
	conclusion = "" if conclusion == c else c
	hide_card()
	_refresh()


func _tape_input(ev: InputEvent) -> void:
	if _done or not (ev is InputEventScreenTouch):
		return
	# select on release without movement, so that dragging the tape sideways does not select
	if ev.pressed:
		_press_x = ev.position.x
		return
	if _press_x < 0.0 or absf(ev.position.x - _press_x) > 24.0:
		_press_x = -1.0
		return
	_press_x = -1.0
	tap_tape_hour(_t0 + (ev.position.x - TAPE_PAD) / PX_PER_H)


## Tap on the tape at an hour (since 10 Oct 00:00). Returns the zone id or "".
func tap_tape_hour(h: float) -> String:
	var id := CompareLogic.tape_hit(_zones, h)
	if id != "":
		toggle(id)
	return id


func _refresh() -> void:
	var sel_style := _compact(UiKit.BRASS.darkened(0.35), UiKit.LAMP, 5)
	var norm := _compact(UiKit.LAKE_DUSK.lerp(UiKit.INK, 0.3), UiKit.BRASS, 2)
	var hov := _compact(UiKit.LAKE_DUSK.lerp(UiKit.BRASS, 0.25), UiKit.LAMP, 2)
	for id in _frag_buttons:
		var b: Button = _frag_buttons[id]
		b.add_theme_stylebox_override("normal", sel_style if id in selected else norm)
		b.add_theme_stylebox_override("hover", sel_style if id in selected else hov)
	for c in _concl_buttons:
		var cb: Button = _concl_buttons[c]
		cb.add_theme_stylebox_override("normal", sel_style if c == conclusion else norm)
		cb.add_theme_stylebox_override("hover", sel_style if c == conclusion else hov)
	for d in _tabs:
		(_tabs[d] as Button).modulate = Color.WHITE if d == _doc else Color(1, 1, 1, 0.6)
	_picked.text = Game.t("pz.gate02.picked", {"n": selected.size()})
	_done_btn.disabled = not CompareLogic.can_submit(selected, conclusion) or _done
	_tape.queue_redraw()


func _check() -> void:
	if _done or not CompareLogic.can_submit(selected, conclusion):
		return
	var r := CompareLogic.check(selected, conclusion, _v)
	if r["ok"]:
		finish()
		_refresh()
		return
	wrong(r["rule"], r["n"], r["m"])
	if level() == "easy":
		selected = Array(r["keep"])
		if not r["keep_conclusion"]:
			conclusion = ""
	else:
		selected = []
		conclusion = ""
	_refresh()


# ------------------------------------------------------------ the tape

func _x(hour: float) -> float:
	return TAPE_PAD + (hour - _t0) * PX_PER_H


func _draw_tape() -> void:
	var w := _tape.size.x
	var font := ThemeDB.fallback_font
	_tape.draw_rect(Rect2(Vector2(0, 0), Vector2(w, TAPE_H)), UiKit.IVORY)
	var up := Rect2(Vector2(0, 34), Vector2(w, 82))        # rain pen band
	var low := Rect2(Vector2(0, 128), Vector2(w, 66))      # wind pen band (three lanes)
	_tape.draw_line(Vector2(0, up.end.y), Vector2(w, up.end.y), Color(UiKit.INK, 0.35), 1.0)
	for k in 3:
		_tape.draw_line(Vector2(0, low.position.y + k * low.size.y / 3.0), Vector2(w, low.position.y + k * low.size.y / 3.0), Color(UiKit.INK, 0.2), 1.0)
	var every := int(_v.get("tape", {}).get("hour_labels_every", 3))
	var h := ceilf(_t0)
	while h <= _t1:
		var x := _x(h)
		var hod := int(h) % 24
		_tape.draw_line(Vector2(x, 30), Vector2(x, TAPE_H - 10), Color(UiKit.INK, 0.5 if hod == 0 else 0.15), 2.0 if hod == 0 else 1.0)
		if hod % every == 0:
			_tape.draw_string(font, Vector2(x + 3, TAPE_H - 2), str(hod), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.INK)
		if hod == 0:
			_tape.draw_string(font, Vector2(x + 4, 24), str(CompareLogic.TAPE_EPOCH_DAY + int(h) / 24), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiKit.WALNUT)
		h += 1.0
	# legend on easy: a drop at the upper pen band (same drop as on the pen bracket)
	if str(_v.get("tape", {}).get("legend", "")) == "drop_icon":
		_drop(Vector2(TAPE_PAD * 0.5, up.get_center().y), 14)
	# upper pen: flat line at the bottom of its band, high saw-tooth when raised (rain)
	var base_y := up.end.y - 8
	var pts := PackedVector2Array([Vector2(_x(_t0), base_y)])
	var spans := CompareLogic.rain_spans(_v)
	spans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["from"] < b["from"])
	for s in spans:
		var amp: float = {"low": 18.0, "medium": 34.0, "high": 60.0}.get(s["height"], 60.0)
		pts.append(Vector2(_x(s["from"]), base_y))
		var x := _x(s["from"])
		var up_tooth := true
		while x < _x(s["to"]):
			x += 6.0
			pts.append(Vector2(minf(x, _x(s["to"])), base_y - (amp if up_tooth else amp * 0.55)))
			up_tooth = not up_tooth
		pts.append(Vector2(_x(s["to"]), base_y))
	pts.append(Vector2(_x(_t1), base_y))
	_tape.draw_polyline(pts, Color("#1d3a7a"), 2.0)
	# lower pen (wind): wavy line moving between the lanes; icons boat / roof / gate on the margin
	var wp := PackedVector2Array()
	var hh := _t0
	while hh <= _t1:
		var lane := 1.0 + sin(hh / 9.0) * 0.9 + sin(hh / 3.1) * 0.15
		wp.append(Vector2(_x(hh), low.position.y + (lane + 0.5) * low.size.y / 3.0 - low.size.y / 6.0))
		hh += 0.5
	_tape.draw_polyline(wp, Color("#1d3a7a"), 2.0)
	_lane_icons(low)
	# zones: underlined on easy ("what can be picked"), pen underline when picked
	for z in _zones:
		var x0 := _x(z["from"])
		var x1 := _x(z["to"])
		if bool(_v.get("fragments_marked", false)):
			_tape.draw_line(Vector2(x0, up.end.y + 4), Vector2(x1, up.end.y + 4), Color(UiKit.INK, 0.45), 2.0)
		if z["id"] in selected:
			_tape.draw_rect(Rect2(Vector2(x0, up.position.y - 4), Vector2(x1 - x0, up.size.y + 8)), Color(UiKit.BRASS, 0.25))
			_tape.draw_line(Vector2(x0, up.end.y + 6), Vector2(x1, up.end.y + 6), UiKit.MAPLE, 6.0)


func _drop(c: Vector2, r: float) -> void:
	_tape.draw_circle(c + Vector2(0, r * 0.3), r * 0.7, Color("#1d3a7a"))
	_tape.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.62, r * 0.05), c + Vector2(0, -r), c + Vector2(r * 0.62, r * 0.05)]), Color("#1d3a7a"))


func _lane_icons(low: Rect2) -> void:
	var lh := low.size.y / 3.0
	var x := 18.0
	var col := UiKit.INK
	# boat
	var y0 := low.position.y + lh * 0.5
	_tape.draw_colored_polygon(PackedVector2Array([Vector2(x - 12, y0), Vector2(x + 12, y0), Vector2(x + 7, y0 + 7), Vector2(x - 7, y0 + 7)]), col)
	_tape.draw_line(Vector2(x, y0), Vector2(x, y0 - 9), col, 2.0)
	# roof
	var y1 := low.position.y + lh * 1.5
	_tape.draw_polyline(PackedVector2Array([Vector2(x - 12, y1 + 6), Vector2(x, y1 - 6), Vector2(x + 12, y1 + 6)]), col, 3.0)
	# gate
	var y2 := low.position.y + lh * 2.5
	for dx in [-10.0, -3.0, 4.0, 11.0]:
		_tape.draw_line(Vector2(x + dx, y2 - 8), Vector2(x + dx, y2 + 8), col, 2.0)


func show_card(title: String, body: String, body_color: Color = UiKit.IVORY) -> void:
	super.show_card(title, body, body_color)
	_picked.visible = not card_visible()


func hide_card() -> void:
	super.hide_card()
	_picked.visible = true
