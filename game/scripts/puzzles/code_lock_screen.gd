class_name CodeLockScreen
extends Overlay
## T01 code lock (PZ-GATE-01) on data (дизайн 5.3 T01, 3.12): brass plate, engraving "pillars with bowls"
## (one per drum), N drums 0–9 (swipe up/down or tap the upper/lower half), handle checks the code.
## Reactions by level: easy — what is wrong; normal — "Wrong" + line; hard — only "Wrong".

signal solved(pz: String)

var pz := "PZ-GATE-01"
var _v: Dictionary
var _digits: Array = []
var _drums: Array = []
var _feedback: RichTextLabel
var _plate: Control
var _drag_start := {}
var _done := false
var _shake := 0.0
var _handle: Button


func setup(puzzle_id: String) -> CodeLockScreen:
	pz = puzzle_id
	return self


func _ready() -> void:
	Game.current_puzzle = pz
	_v = Game.data.values(pz, Game.state.difficulty)
	var n := CodeLockLogic.code_length(_v)
	var saved: Variant = Game.state.puzzle_progress.get(pz, {}).get("drums")
	_digits = saved if typeof(saved) == TYPE_ARRAY and saved.size() == n else []
	if _digits.is_empty():
		for i in n:
			_digits.append(0)
	add_child(UiKit.dim_layer(0.85))
	_plate = Control.new()
	_plate.anchor_left = 0.5; _plate.anchor_right = 0.5; _plate.anchor_top = 0.5; _plate.anchor_bottom = 0.5
	var w := 180.0 * n + 160.0
	_plate.offset_left = -w / 2; _plate.offset_right = w / 2; _plate.offset_top = -330; _plate.offset_bottom = 110
	_plate.draw.connect(_draw_plate)
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	for i in n:
		var d := Control.new()
		d.custom_minimum_size = Vector2(140, 220)
		d.position = Vector2(80 + i * 180 + 20, 170)
		d.size = Vector2(140, 220)
		d.mouse_filter = Control.MOUSE_FILTER_STOP
		d.gui_input.connect(_drum_input.bind(i))
		d.draw.connect(_draw_drum.bind(d, i))
		_plate.add_child(d)
		_drums.append(d)
	var handle := UiKit.button(Game.t("pz.handle"), 360, true)
	_handle = handle
	handle.anchor_left = 0.5; handle.anchor_right = 0.5; handle.anchor_top = 1.0; handle.anchor_bottom = 1.0
	handle.offset_left = -180; handle.offset_right = 180; handle.offset_top = -100 - UiKit.BIG_TAP; handle.offset_bottom = -100
	handle.pressed.connect(_check)
	add_child(handle)
	_feedback = UiKit.rich(UiKit.FONT_SUB, UiKit.LAMP)
	_feedback.anchor_left = 0.17; _feedback.anchor_right = 0.79; _feedback.anchor_top = 1.0; _feedback.anchor_bottom = 1.0
	_feedback.offset_top = -92; _feedback.offset_bottom = -8
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_feedback)
	add_back_button()
	if not Game.state.has("tut.UI-TUT-05"):
		Game.state.set_flag("tut.UI-TUT-05")
		_feedback.text = "[i]%s[/i]" % Game.t("UI-TUT-05")


func _exit_tree() -> void:
	if Game.current_puzzle == pz:
		Game.current_puzzle = ""
	if Game.state:
		Game.state.puzzle_progress[pz] = {"drums": _digits}


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_plate.position.x = (get_rect().size.x - _plate.size.x) * 0.5 + sin(_shake * 60.0) * 14.0 * (_shake / 0.4)


func _drum_input(ev: InputEvent, i: int) -> void:
	if _done:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_drag_start[i] = ev.position
		elif _drag_start.has(i):
			var dy: float = ev.position.y - _drag_start[i].y
			if absf(dy) > 30.0:
				_turn(i, -1 if dy > 0 else 1)     # swipe up → next digit
			else:
				_turn(i, 1 if ev.position.y < 110 else -1)
			_drag_start.erase(i)
		accept_event()


func _turn(i: int, step: int) -> void:
	_digits[i] = (int(_digits[i]) + step + 10) % 10
	(_drums[i] as Control).queue_redraw()


func _answer() -> String:
	var s := ""
	for d in _digits:
		s += str(int(d))
	return s


func _check() -> void:
	if _done:
		return
	var ans := _answer()
	var ok := CodeLockLogic.is_correct(ans, _v)
	Game.state.record_attempt(pz, ok)
	if ok:
		_done = true
		_handle.visible = false
		var params := CodeLockLogic.logic_params(_v, Game.lang(), Game.data)
		var logic: String = Game.data.node(pz).get("logic_line", "")
		Game.state.note_line(logic)
		_feedback.text = "[b]%s[/b]\n[i]%s[/i]" % [Game.t("pz.solved"), UiKit.escape_bb(Game.line(logic, params))]
		_feedback.offset_top = -205
		_plate.queue_redraw()
		await get_tree().create_timer(0.3).timeout
		var cont := UiKit.button(Game.t("btn.next"), 280, true)
		cont.anchor_left = 1.0; cont.anchor_right = 1.0; cont.anchor_top = 1.0; cont.anchor_bottom = 1.0
		cont.offset_left = -310; cont.offset_right = -24; cont.offset_top = -24 - UiKit.BIG_TAP; cont.offset_bottom = -24
		cont.pressed.connect(func() -> void:
			solved.emit(pz)
			close())
		add_child(cont)
		return
	var rule := CodeLockLogic.classify(ans, _v, Game.data.values("IT-OWL", Game.state.difficulty).get("owl_base_signs", []), Game.data)
	var fb := CodeLockLogic.feedback(rule, Game.state.difficulty, Game.data.node(pz))
	var parts: Array = []
	if fb["ui"] != "":
		parts.append("[b]%s[/b]" % Game.t(fb["ui"]))
	if fb["line"] != "":
		Game.state.note_line(fb["line"])
		parts.append("[i]%s[/i]" % UiKit.escape_bb(Game.line(fb["line"])))
	_feedback.text = "  ".join(parts)
	_shake = 0.4


func _draw_plate() -> void:
	var r := Rect2(Vector2.ZERO, _plate.size)
	_plate.draw_rect(r, UiKit.BRASS.darkened(0.15))
	_plate.draw_rect(r, UiKit.INK, false, 6.0)
	_plate.draw_rect(r.grow(-14), UiKit.LAMP.darkened(0.25), false, 2.0)
	# engraving: little pillars with bowls, one above each drum (detail layer, count = drums)
	var n := _digits.size()
	for i in n:
		var x := 80.0 + i * 180.0 + 90.0
		_plate.draw_rect(Rect2(Vector2(x - 14, 70), Vector2(28, 70)), Color(0, 0, 0, 0), false, 3.0)
		_plate.draw_line(Vector2(x - 14, 70), Vector2(x - 14, 140), UiKit.INK, 3.0)
		_plate.draw_line(Vector2(x + 14, 70), Vector2(x + 14, 140), UiKit.INK, 3.0)
		_plate.draw_arc(Vector2(x, 58), 30, 0, PI, 16, UiKit.INK, 3.0)
		_plate.draw_line(Vector2(x - 30, 58), Vector2(x + 30, 58), UiKit.INK, 3.0)
	if _done:
		_plate.draw_rect(Rect2(Vector2(r.size.x - 70, r.size.y * 0.5 - 20), Vector2(50, 40)), UiKit.INK)


func _draw_drum(d: Control, i: int) -> void:
	var r := Rect2(Vector2.ZERO, d.size)
	d.draw_rect(r, UiKit.IVORY)
	d.draw_rect(r, UiKit.INK, false, 4.0)
	var font := ThemeDB.fallback_font
	var v := int(_digits[i])
	d.draw_string(font, Vector2(0, 50), str((v + 1) % 10), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(UiKit.INK, 0.35))
	d.draw_string(font, Vector2(0, 138), str(v), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 84, UiKit.INK)
	d.draw_string(font, Vector2(0, 205), str((v + 9) % 10), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 36, Color(UiKit.INK, 0.35))
	d.draw_line(Vector2(0, 72), Vector2(r.size.x, 72), Color(UiKit.INK, 0.4), 2.0)
	d.draw_line(Vector2(0, 156), Vector2(r.size.x, 156), Color(UiKit.INK, 0.4), 2.0)
