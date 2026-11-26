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
	_run()


func _run() -> void:
	var intro := Game.data.event("EV-INTRO")
	for it in intro.get("give_at_start", []):
		Game.state.give(it)
	for fr in intro.get("frames", []):
		_bg.texture = Game.data.texture("intro", fr.get("art", ""))
		for it in fr.get("give", []):
			_owl_layer.visible = true
			_owl_layer.queue_redraw()
			await _wait_tap()
			_owl_layer.visible = false
			Game.state.give(it)
		if fr.get("autosnap") != null:
			Game.state.give(fr["autosnap"])
		var lines: Array = fr.get("lines", [])
		if not lines.is_empty():
			var box := DialogueBox.new()
			add_child(box)
			box.play(lines, "frame")
			await box.finished
		else:
			await _wait_tap()
		if fr.get("id") == "F1":
			Game.state.give("DOC-LETTER")
	# the gate conversation over the blurred panorama
	var dlg := Game.data.event(intro.get("next", "EV-GATE-DIALOG"))
	var vp := Game.data.viewpoint(dlg.get("background", {}).get("vp", "VP-GATE-1"))
	_bg.visible = false
	_pano.visible = true
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


func _wait_tap() -> void:
	var catcher := Control.new()
	UiKit.full_rect(catcher)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	var hint := UiKit.label("▸", 48, UiKit.LAMP)
	hint.anchor_left = 1.0; hint.anchor_right = 1.0; hint.anchor_top = 1.0; hint.anchor_bottom = 1.0
	hint.offset_left = -80; hint.offset_top = -80
	catcher.add_child(hint)
	add_child(catcher)
	await get_tree().create_timer(0.3).timeout
	while true:
		var ev: InputEvent = await _next_input(catcher)
		if ev is InputEventScreenTouch and ev.pressed:
			break
	catcher.queue_free()


func _next_input(c: Control) -> InputEvent:
	var got: Array = []
	var cb := func(ev: InputEvent) -> void: got.append(ev)
	c.gui_input.connect(cb)
	while got.is_empty():
		await get_tree().process_frame
	c.gui_input.disconnect(cb)
	return got[0]


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
