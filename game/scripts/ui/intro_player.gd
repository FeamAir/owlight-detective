class_name IntroPlayer
extends Control
## Prologue EV-INTRO (frames П-1…П-6) and the gate conversation EV-GATE-DIALOG (spec 2.1, 4.1–4.2).
## Frames: illustration background (placeholder), lines in "frame" mode (no portraits). Letter — reading mode.
## П-2 — the owl's base with 4 signs (engine layer) → owl into the bag. Then the dialogue with portraits over
## the blurred VP-GATE-1 panorama. Not skippable (spec 8: «Пропустить» only for cut-scenes).

signal finished

var _bg: TextureRect
var _pano: PanoramaView
var _owl_layer: Control
var _debug_label: Label
var _gate_pano_path := ""
var frame_id := ""                 # current frame (F1…F6, GATE-DIALOG) — for tests and the debug caption


func _ready() -> void:
	UiKit.full_rect(self)
	_pano = PanoramaView.new()
	UiKit.full_rect(_pano)
	_pano.interactive = false
	_pano.visible = false
	add_child(_pano)
	_bg = TextureRect.new()
	UiKit.full_rect(_bg)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_bg)
	_owl_layer = Control.new()
	UiKit.full_rect(_owl_layer)
	_owl_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_owl_layer.draw.connect(_draw_owl)
	_owl_layer.visible = false
	add_child(_owl_layer)
	# the gate panorama (4096×2048, ~60–75 ms to decode on a desktop CPU, several times more on a phone) is decoded
	# in the background while the prologue is read, so the switch to the gate dialogue does not stall
	var gate_vp := Game.data.viewpoint(Game.data.event(Game.data.event("EV-INTRO").get("next", "EV-GATE-DIALOG")).get("background", {}).get("vp", "VP-GATE-1"))
	_gate_pano_path = Game.data.texture_path("pano", str(gate_vp.get("panorama", "")))
	if _gate_pano_path != "":
		ResourceLoader.load_threaded_request(_gate_pano_path)
	_run()


func _run() -> void:
	var intro := Game.data.event("EV-INTRO")
	for it in intro.get("give_at_start", []):
		Game.state.give(it)
	for fr in intro.get("frames", []):
		frame_id = str(fr.get("id", ""))
		var art := str(fr.get("art", ""))
		_bg.texture = Game.data.texture("intro", art)
		_set_debug_caption("intro", art, frame_id)
		var gives: Array = fr.get("give", [])
		var lines: Array = fr.get("lines", [])
		# П-2: the owl's base with its signs stays on screen until ONE tap (owner 28.11: the old second tap on
		# the same frame without the signs looked like a hang)
		_owl_layer.visible = not gives.is_empty()
		_owl_layer.queue_redraw()
		if not gives.is_empty() or lines.is_empty():
			await _wait_tap()
		for it in gives:
			Game.state.give(it)
		if fr.get("autosnap") != null:
			Game.state.give(fr["autosnap"])
		_owl_layer.visible = false
		if not lines.is_empty():
			var box := DialogueBox.new()
			add_child(box)
			box.play(lines, "frame")
			await box.finished
		if fr.get("id") == "F1":
			Game.state.give("DOC-LETTER")
	frame_id = "GATE-DIALOG"
	_set_debug_caption("", "", "")
	# the gate conversation over the blurred panorama
	var dlg := Game.data.event(intro.get("next", "EV-GATE-DIALOG"))
	var vp := Game.data.viewpoint(dlg.get("background", {}).get("vp", "VP-GATE-1"))
	_bg.visible = false
	_pano.visible = true
	var pano_path := Game.data.texture_path("pano", str(vp.get("panorama", "")))
	if pano_path != "" and pano_path == _gate_pano_path:
		_pano.set_texture(ResourceLoader.load_threaded_get(pano_path) as Texture2D)
	else:
		_pano.set_texture(Game.data.texture("pano", vp.get("panorama", "")))
	_pano.look_at_angles(0, 2)
	_pano.blur = 0.0025
	_pano.dim = 0.35
	var box2 := DialogueBox.new()
	add_child(box2)
	box2.play(dlg.get("lines", []), "portraits")
	await box2.finished
	var tw := create_tween()
	tw.tween_property(_pano, "blur", 0.0, 0.6)
	tw.parallel().tween_property(_pano, "dim", 0.0, 0.6)
	await tw.finished
	finished.emit()


## Tap anywhere on the frame continues (TapCatcher: every event is looked at, the guard tap is not lost).
func _wait_tap() -> void:
	var catcher := TapCatcher.new()
	add_child(catcher)
	await catcher.tapped
	catcher.queue_free()


## Owner build with the debug overlay on: what this frame is (frame id, asset, placeholder notes).
## Never in a normal run — the pictures themselves carry no service captions.
func _set_debug_caption(kind: String, asset: String, fid: String) -> void:
	var text := ""
	if Game.debug_overlay_on() and kind != "":
		text = Game.data.debug_caption(kind, asset, fid)
	if text == "":
		if _debug_label:
			_debug_label.visible = false
		return
	if _debug_label == null:
		_debug_label = UiKit.label("", UiKit.FONT_UI - 8, Color(1, 1, 0.7))
		_debug_label.position = Vector2(24, 16)
		_debug_label.size = Vector2(1100, 40)
		_debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_debug_label.add_theme_constant_override("outline_size", 6)
		add_child(_debug_label)
	move_child(_debug_label, -1)
	_debug_label.text = text
	_debug_label.visible = true


func _draw_owl() -> void:
	var signs: Array = Game.data.values("IT-OWL", Game.state.difficulty).get("owl_base_signs", [])
	var c := size * Vector2(0.5, 0.55)
	_owl_layer.draw_circle(c, 220, Color(0.45, 0.33, 0.2))
	_owl_layer.draw_arc(c, 220, 0, TAU, 64, UiKit.INK, 5.0)
	for i in signs.size():
		var a := -PI / 2 + TAU * i / signs.size()
		SignDraw.draw(_owl_layer, signs[i], c + Vector2(cos(a), sin(a)) * 130, 56, UiKit.IVORY, Color(0.25, 0.18, 0.12))


func on_back() -> void:
	pass   # prologue is read, not skipped
