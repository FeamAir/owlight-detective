class_name DialogueBox
extends Control
## Dialogue screen (дизайн 3.9): portraits (speaker brighter and higher), name tab on the speaker's side,
## typewriter text, tap = finish line / next line (250 ms guard), log button. Voice-ready: every line is a
## record with audio_ru/audio_en; the replay button slot is reserved (hidden until voice-over).
## Modes: "portraits" — over the blurred panorama; "frame" — over a prologue illustration, no portraits.

signal finished

const GUARD_MS := 250

var lines: Array = []
var mode := "portraits"
var _i := -1
var _shown_chars := 0.0
var _full := ""
var _changed_at := 0
var _plate: PanelContainer
var _name_tab: PanelContainer
var _name_label: Label
var _text: RichTextLabel
var _more: ContinueHint
var _pending_tap := false          # tap during the guard: not lost, applied when the guard ends
var _left: TextureRect
var _right: TextureRect
var _left_speaker := ""
var _log_btn: Button
var _replay_slot: Control
var _letter: PanelContainer
var _letter_text: RichTextLabel


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_left = TextureRect.new()
	_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_left.anchor_left = 0.0; _left.anchor_right = 0.0; _left.anchor_top = 1.0; _left.anchor_bottom = 1.0
	_left.offset_left = 40; _left.offset_right = 520; _left.offset_top = -640; _left.offset_bottom = -40
	_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_left)
	_right = TextureRect.new()
	_right.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right.flip_h = true
	_right.anchor_left = 1.0; _right.anchor_right = 1.0; _right.anchor_top = 1.0; _right.anchor_bottom = 1.0
	_right.offset_left = -440; _right.offset_right = -60; _right.offset_top = -500; _right.offset_bottom = -40
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_right)

	_plate = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiKit.LAKE_DUSK, 0.92)
	sb.border_color = UiKit.BRASS
	sb.border_width_top = 3
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 36; sb.content_margin_right = 140; sb.content_margin_top = 26; sb.content_margin_bottom = 40
	_plate.add_theme_stylebox_override("panel", sb)
	_plate.anchor_left = 0.0; _plate.anchor_right = 1.0; _plate.anchor_top = 1.0; _plate.anchor_bottom = 1.0
	_plate.offset_left = 32; _plate.offset_right = -32; _plate.offset_top = -230; _plate.offset_bottom = -24
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_text = UiKit.rich(UiKit.FONT_SUB)
	_text.fit_content = false
	_plate.add_child(_text)

	_name_tab = PanelContainer.new()
	var nsb := StyleBoxFlat.new()
	nsb.bg_color = UiKit.BRASS.darkened(0.25)
	nsb.set_corner_radius_all(10)
	nsb.content_margin_left = 22; nsb.content_margin_right = 22; nsb.content_margin_top = 6; nsb.content_margin_bottom = 6
	_name_tab.add_theme_stylebox_override("panel", nsb)
	_name_tab.anchor_top = 1.0; _name_tab.anchor_bottom = 1.0
	_name_tab.offset_top = -280; _name_tab.offset_bottom = -228
	_name_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label = UiKit.label("", UiKit.FONT_UI, UiKit.IVORY)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_name_tab.add_child(_name_label)
	add_child(_name_tab)

	# «Нажмите, чтобы продолжить ▸» at the bottom edge of the plate / letter (owner 28.11)
	_more = ContinueHint.new()
	_more.anchor_left = 1.0; _more.anchor_right = 1.0; _more.anchor_top = 1.0; _more.anchor_bottom = 1.0
	_more.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_more.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_more.offset_left = -50; _more.offset_right = -50; _more.offset_top = -34; _more.offset_bottom = -34
	add_child(_more)
	# reserved place for "replay line" (появится с озвучкой, решение №11) — 48 dp, hidden
	_replay_slot = Control.new()
	_replay_slot.custom_minimum_size = Vector2(UiKit.TAP, UiKit.TAP)
	_replay_slot.visible = false
	add_child(_replay_slot)

	_log_btn = UiKit.button(Game.t("nb.tab.log"))
	_log_btn.anchor_left = 1.0; _log_btn.anchor_right = 1.0
	_log_btn.offset_left = -520; _log_btn.offset_right = -180; _log_btn.offset_top = 24; _log_btn.offset_bottom = 24 + UiKit.TAP
	_log_btn.pressed.connect(_open_log)
	add_child(_log_btn)

	_letter = PanelContainer.new()
	_letter.add_theme_stylebox_override("panel", UiKit.paper_box())
	_letter.anchor_left = 0.06; _letter.anchor_right = 0.94; _letter.anchor_top = 0.03; _letter.anchor_bottom = 0.97
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter_text = UiKit.rich(UiKit.FONT_UI - 2, UiKit.INK)
	_letter_text.fit_content = false
	_letter.add_child(_letter_text)
	_letter.visible = false
	add_child(_letter)
	move_child(_more, -1)              # the hint stays readable over the letter too


func play(line_ids: Array, play_mode: String = "portraits") -> void:
	lines = line_ids.duplicate()
	mode = play_mode
	_i = -1
	_left_speaker = ""
	_next()


func _next() -> void:
	_i += 1
	if _i >= lines.size():
		finished.emit()
		queue_free()
		return
	var id: String = lines[_i]
	Game.state.note_line(id)
	_changed_at = Time.get_ticks_msec()
	_pending_tap = false
	_more.restart()
	var ln := Game.data.line(id)
	var style := str(ln.get("style", "speech"))
	var text := UiKit.escape_bb(Game.line(id))
	if style == "letter":
		_letter.visible = true
		_plate.visible = false
		_name_tab.visible = false
		_left.visible = false
		_right.visible = false
		_letter_text.text = text
		_full = text
		_shown_chars = 1e9
		_letter_text.visible_characters = -1
		_more.visible = true
		return
	_letter.visible = false
	_plate.visible = true
	_name_tab.visible = true
	_full = "[i]%s[/i]" % text if style == "thought" else text
	_text.text = _full
	_shown_chars = 0.0 if Game.settings["text_speed"] != "instant" else 1e9
	_text.visible_characters = 0 if _shown_chars < 1.0 else -1
	_name_label.text = Game.speaker_name(id)
	var speaker := str(ln.get("speaker_id", ""))
	var sp := Game.data.speaker(speaker)
	var is_right: bool = sp.get("side", "left") == "right"
	_name_tab.anchor_left = 1.0 if is_right else 0.0
	_name_tab.anchor_right = _name_tab.anchor_left
	_name_tab.offset_left = -420.0 if is_right else 60.0
	_name_tab.offset_right = -60.0 if is_right else 420.0
	_update_portraits(speaker, str(ln.get("emotion", "")), style)


func _portrait(speaker: String, emotion: String) -> Texture2D:
	var sp := Game.data.speaker(speaker)
	if sp.get("portrait") == null:
		return null
	var emo := emotion if emotion != "" and emotion != "<null>" else str(sp.get("default_emotion", ""))
	var tex := Game.data.texture("portraits", "%s_%s" % [sp["portrait"], emo])
	if tex == null:
		tex = Game.data.texture("portraits", "%s_%s" % [sp["portrait"], sp.get("default_emotion", "")])
	return tex


func _update_portraits(speaker: String, emotion: String, _style: String) -> void:
	if mode != "portraits":
		_left.visible = false
		_right.visible = false
		return
	var sp := Game.data.speaker(speaker)
	var side := str(sp.get("side", "none"))
	if side == "left":
		_left_speaker = speaker
		_left.texture = _portrait(speaker, emotion)
	elif side == "right":
		_right.texture = _portrait(speaker, emotion)
	_left.visible = _left.texture != null
	_right.visible = _right.texture != null
	# the speaker is brighter and higher; the listener is dimmed 40 % and 16 dp lower (дизайн 3.9)
	var left_talks := side == "left"
	_left.modulate = Color(1, 1, 1) if left_talks else Color(0.6, 0.6, 0.6)
	_right.modulate = Color(1, 1, 1) if side == "right" else Color(0.6, 0.6, 0.6)
	_left.offset_top = -640.0 if left_talks else -608.0
	_left.offset_bottom = -40.0 if left_talks else -8.0
	_right.offset_top = -500.0 if side == "right" else -468.0
	_right.offset_bottom = -40.0 if side == "right" else -8.0


func _process(delta: float) -> void:
	if _shown_chars < 1e8:
		var cps := 60.0 if Game.settings["text_speed"] == "fast" else 35.0
		_shown_chars += delta * cps
		_text.visible_characters = int(_shown_chars)
		if _text.visible_characters >= _text.get_total_character_count():
			_shown_chars = 1e9
			_text.visible_characters = -1
	_more.visible = _shown_chars >= 1e8
	if _pending_tap and Time.get_ticks_msec() - _changed_at >= GUARD_MS:
		_pending_tap = false
		_advance()


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch and ev.pressed:
		accept_event()
		if Time.get_ticks_msec() - _changed_at < GUARD_MS:
			_pending_tap = true
			return
		_advance()


## Tap anywhere on the dialogue: finish the typing line, or go to the next line.
func _advance() -> void:
	if _shown_chars < 1e8:
		_shown_chars = 1e9
		_text.visible_characters = -1
	else:
		_next()


func _open_log() -> void:
	var log_panel := LogPanel.new()
	add_child(log_panel)
