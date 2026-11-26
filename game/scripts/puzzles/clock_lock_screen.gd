class_name ClockLockScreen
extends PuzzleScreen
## T19 key box (PZ-GATE-03, test-set GATE-03 + spec 5.5): oak box with a glass door, brass dial 1–12
## without minute marks, two hands (the minute hand ends in a little owl), tag "For the guest off the train".
## Drag a hand round the dial (snaps to snap_minutes: Л 10, Н 5, С 1) or use the −/+ buttons; the latch
## checks the time. A wrong time: the latch does not give, the hands stay. Reactions by level (4.4).

var t := 0                      # dial time, minutes 0…719 (0 = 12:00, where the hands start)
var _dial: Control
var _drag_hand := ""            # "hour" | "minute" | ""
var _shake := 0.0
var _open := 0.0                # door animation 0…1 after solving
var _readout: Label


func _build() -> void:
	var saved: Variant = Game.state.puzzle_progress.get(pz, {}).get("t")
	t = ClockLockLogic.snap(int(saved), _v) if saved != null else 0
	add_child(UiKit.dim_layer(0.88))
	_dial = Control.new()
	UiKit.full_rect(_dial)
	_dial.mouse_filter = Control.MOUSE_FILTER_STOP
	_dial.draw.connect(_draw_box)
	_dial.gui_input.connect(_dial_input)
	add_child(_dial)
	# −/+ for hour and minutes (fine control and accessibility; dragging works as well)
	var col := VBoxContainer.new()
	col.anchor_left = 1.0; col.anchor_right = 1.0
	col.offset_left = -420; col.offset_right = -40; col.offset_top = 150
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	_readout = UiKit.label("", UiKit.FONT_TITLE, UiKit.LAMP)
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_readout)
	for row in [["hour", 60], ["minute", ClockLockLogic.snap_step(_v)]]:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		var minus := UiKit.button("−", UiKit.TAP)
		minus.pressed.connect(_step.bind(-int(row[1])))
		h.add_child(minus)
		var l := UiKit.label(Game.t("pz.gate03." + str(row[0])), UiKit.FONT_UI, UiKit.IVORY)
		l.custom_minimum_size.x = 150
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.add_child(l)
		var plus := UiKit.button("+", UiKit.TAP)
		plus.pressed.connect(_step.bind(int(row[1])))
		h.add_child(plus)
		col.add_child(h)
	if Game.state.inventory.has("IT-TICKET"):
		var tb := UiKit.button(Game.t("doc.ticket.title"), 300)
		tb.pressed.connect(func() -> void: add_child(DocumentView.new().setup("DOC-TICKET")))
		col.add_child(tb)
	var latch := add_action_button(Game.t("pz.gate03.latch"), 320)
	latch.pressed.connect(_check)
	_update_readout()


func _ready() -> void:
	super._ready()
	show_card("", Game.t("pz.gate03.hint_drag"), UiKit.FOG)


func _save_progress() -> void:
	Game.state.puzzle_progress[pz] = {"t": t}


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_dial.queue_redraw()
	if _done and _open < 1.0:
		_open = minf(1.0, _open + delta * 1.5)
		_dial.queue_redraw()


func _centre() -> Vector2:
	var vs := get_viewport_rect().size
	return Vector2(vs.x * 0.40, vs.y * 0.44)


func _radius() -> float:
	return get_viewport_rect().size.y * 0.36      # dial ≥ 70 % of the screen height (визуальное ТЗ)


func set_time(minutes: int) -> void:
	t = ClockLockLogic.snap(minutes, _v)
	_update_readout()
	_dial.queue_redraw()


func _step(d: int) -> void:
	if _done:
		return
	set_time(t + d)


func _update_readout() -> void:
	_readout.text = ClockLockLogic.fmt(t)


func _dial_input(ev: InputEvent) -> void:
	if _done:
		return
	var pos: Vector2
	if ev is InputEventScreenTouch:
		pos = ev.position
		if ev.pressed:
			var d := pos.distance_to(_centre())
			if d > _radius() * 1.1:
				return
			_drag_hand = "hour" if d < _radius() * 0.5 else "minute"
			_drag_to(pos)
		else:
			_drag_hand = ""
		accept_event()
	elif ev is InputEventScreenDrag and _drag_hand != "":
		_drag_to(ev.position)
		accept_event()


func _drag_to(pos: Vector2) -> void:
	var v := pos - _centre()
	if v.length() < 8.0:
		return
	var ang := atan2(v.x, -v.y)        # 0 at 12 o'clock, clockwise
	if _drag_hand == "minute":
		set_time(ClockLockLogic.drag_minute(t, ang, _v))
	else:
		set_time(ClockLockLogic.drag_hour(t, ang))


func _check() -> void:
	if _done:
		return
	if ClockLockLogic.is_correct(t, _v):
		finish("pz.solved")
		return
	wrong(ClockLockLogic.classify(t, _v))
	_shake = 0.4


func _draw_box() -> void:
	var c := _centre()
	var r := _radius()
	var sx := sin(_shake * 60.0) * 10.0 * (_shake / 0.4)
	c.x += sx
	# oak box with a glass door
	var box := Rect2(c - Vector2(r * 1.35, r * 1.18), Vector2(r * 2.7, r * 2.36))
	_dial.draw_rect(box, UiKit.WALNUT)
	_dial.draw_rect(box, UiKit.INK, false, 6.0)
	var door := box.grow(-r * 0.1)
	# behind the glass: hooks, faded empty tags, the key "Study"
	for i in 5:
		var hx := door.position.x + door.size.x * (0.14 + 0.18 * i)
		var hy := door.position.y + door.size.y * 0.12
		_dial.draw_circle(Vector2(hx, hy), 6, UiKit.BRASS)
		if i == 2:
			continue
		_dial.draw_rect(Rect2(Vector2(hx - 12, hy + 10), Vector2(24, 34)), Color(UiKit.IVORY, 0.18))
	var key_p := Vector2(door.get_center().x, door.position.y + door.size.y * 0.12)
	_dial.draw_line(key_p, key_p + Vector2(0, 70), UiKit.BRASS, 6.0)
	_dial.draw_circle(key_p + Vector2(0, 12), 12, UiKit.BRASS)
	var font := ThemeDB.fallback_font
	var tag_w := font.get_string_size(Game.t("pz.gate03.key_tag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 16
	_dial.draw_rect(Rect2(key_p + Vector2(12, 40), Vector2(tag_w, 34)), UiKit.IVORY)
	_dial.draw_string(font, key_p + Vector2(20, 64), Game.t("pz.gate03.key_tag"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.INK)
	# glass door (swings open after solving)
	var glass := door
	glass.size.x *= (1.0 - _open * 0.85)
	_dial.draw_rect(glass, Color(0.75, 0.85, 0.9, 0.16))
	_dial.draw_rect(glass, UiKit.BRASS.darkened(0.2), false, 4.0)
	# the dial: brass, numbers 1–12, no minute marks
	if _open < 0.5:
		_dial.draw_circle(c, r * 0.72, UiKit.BRASS.darkened(0.1))
		_dial.draw_arc(c, r * 0.72, 0, TAU, 72, UiKit.INK, 5.0)
		for h in range(1, 13):
			var a := TAU * h / 12.0
			var p := c + Vector2(sin(a), -cos(a)) * r * 0.58
			_dial.draw_string(font, p + Vector2(-24, 13), str(h), HORIZONTAL_ALIGNMENT_CENTER, 48, int(r * 0.13), UiKit.INK)
		_draw_hand(c, ClockLockLogic.hour_angle(t), r * 0.36, 12.0, false)
		_draw_hand(c, ClockLockLogic.minute_angle(t), r * 0.60, 7.0, true)
		_dial.draw_circle(c, 12, UiKit.INK)
		# latch under the dial
		_dial.draw_rect(Rect2(c + Vector2(-22, r * 0.8), Vector2(44, 26 + (0 if not _done else 10))), UiKit.BRASS.darkened(0.35))
	# tag "For the guest off the train" tied to the handle
	var tag := Rect2(box.position + Vector2(-r * 0.62, r * 0.25), Vector2(r * 0.6, r * 0.42))
	_dial.draw_line(tag.position + Vector2(tag.size.x, 10), box.position + Vector2(8, r * 0.35), UiKit.IVORY, 2.0)
	_dial.draw_rect(tag, UiKit.IVORY)
	_dial.draw_multiline_string(font, tag.position + Vector2(10, 30), Game.t("pz.gate03.tag"), HORIZONTAL_ALIGNMENT_CENTER, tag.size.x - 20, 22, -1, UiKit.INK)


func _draw_hand(c: Vector2, ang: float, length: float, width: float, owl: bool) -> void:
	var dir := Vector2(sin(ang), -cos(ang))
	var tip := c + dir * length
	_dial.draw_line(c - dir * 18.0, tip, UiKit.INK, width)
	if owl:
		SignDraw.draw(_dial, "owl", tip, 20, UiKit.INK, UiKit.BRASS.lightened(0.2))
	else:
		_dial.draw_circle(tip, width * 0.9, UiKit.INK)
