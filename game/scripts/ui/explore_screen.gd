class_name ExploreScreen
extends Control
## Game screen (дизайн 3.5): panorama, 4 corner buttons (menu, «Мысли», bag, notebook), subtitles,
## toasts, tutorial prompts, fades between viewpoints; opens close-ups, puzzles, documents, dialogue.

signal request_main_menu
signal slice_finished

const FADE := 0.35

var pano: PanoramaView
var _overlays: Control
var _hud: Control
var _fade: ColorRect
var _sub_panel: PanelContainer
var _sub_text: RichTextLabel
var _sub_queue: Array = []
var _sub_time := 0.0
var _toast: Label
var _toast_queue: Array = []
var _toast_time := 0.0
var _tut: Label
var _hint_btn: HintButton
var _bag_btn: Button
var _nb_btn: Button
var _exits: Array = []
var _busy := false


func _ready() -> void:
	UiKit.full_rect(self)
	pano = PanoramaView.new()
	UiKit.full_rect(pano)
	add_child(pano)
	pano.tapped.connect(_on_tapped)
	pano.long_pressed.connect(_on_long_press)
	pano.swiped.connect(func() -> void: _tutorial_event("swipe"))
	_build_hud()
	_overlays = Control.new()
	UiKit.full_rect(_overlays)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlays)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	UiKit.full_rect(_fade)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	Game.state_changed.connect(_refresh_hud)
	Game.hint_ready.connect(func() -> void: _hint_btn.pulse())


# ------------------------------------------------------------ HUD

func _corner_button(text: String, anchor: Vector2, offset: Vector2, w: float) -> Button:
	var b := UiKit.button(text, w)
	b.custom_minimum_size.y = UiKit.BIG_TAP
	b.anchor_left = anchor.x; b.anchor_right = anchor.x; b.anchor_top = anchor.y; b.anchor_bottom = anchor.y
	b.offset_left = offset.x; b.offset_right = offset.x + w
	b.offset_top = offset.y; b.offset_bottom = offset.y + UiKit.BIG_TAP
	_hud.add_child(b)
	return b


func _build_hud() -> void:
	_hud = Control.new()
	UiKit.full_rect(_hud)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var menu := _corner_button("≡", Vector2(0, 0), Vector2(32, 24), UiKit.BIG_TAP)
	menu.pressed.connect(open_pause)
	_nb_btn = _corner_button(Game.t("hud.notebook"), Vector2(1, 1), Vector2(-32 - 250, -24 - UiKit.BIG_TAP), 250)
	_nb_btn.pressed.connect(func() -> void: _open(NotebookPanel.new()))
	_bag_btn = _corner_button(Game.t("hud.bag"), Vector2(1, 1), Vector2(-32 - 250 - 16 - 220, -24 - UiKit.BIG_TAP), 220)
	_bag_btn.pressed.connect(func() -> void: _open(BagPanel.new()))
	_hint_btn = HintButton.new()
	_hint_btn.anchor_left = 1.0; _hint_btn.anchor_right = 1.0
	_hint_btn.offset_left = -32 - UiKit.BIG_TAP; _hint_btn.offset_right = -32; _hint_btn.offset_top = 24; _hint_btn.offset_bottom = 24 + UiKit.BIG_TAP
	_hint_btn.pressed.connect(_on_hint)
	_hud.add_child(_hint_btn)

	_sub_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiKit.LAKE_DUSK, 0.85)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 28; sb.content_margin_right = 28; sb.content_margin_top = 14; sb.content_margin_bottom = 14
	_sub_panel.add_theme_stylebox_override("panel", sb)
	_sub_panel.anchor_left = 0.2; _sub_panel.anchor_right = 0.8; _sub_panel.anchor_top = 1.0; _sub_panel.anchor_bottom = 1.0
	_sub_panel.offset_top = -24 - UiKit.BIG_TAP - 150; _sub_panel.offset_bottom = -24 - UiKit.BIG_TAP - 16
	_sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub_panel.visible = false
	_sub_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			_sub_time = 0.0)
	_sub_text = UiKit.rich(UiKit.FONT_SUB)
	_sub_panel.add_child(_sub_text)
	_hud.add_child(_sub_panel)

	_toast = UiKit.label("", UiKit.FONT_UI, UiKit.LAMP)
	_toast.anchor_left = 0.25; _toast.anchor_right = 0.75
	_toast.offset_top = 24; _toast.offset_bottom = 90
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", UiKit.INK)
	_toast.add_theme_constant_override("outline_size", 8)
	_hud.add_child(_toast)

	_tut = UiKit.label("", UiKit.FONT_SUB, UiKit.IVORY)
	_tut.anchor_left = 0.2; _tut.anchor_right = 0.8; _tut.anchor_top = 0.5; _tut.anchor_bottom = 0.5
	_tut.offset_top = -210; _tut.offset_bottom = -140
	_tut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tut.add_theme_color_override("font_outline_color", UiKit.INK)
	_tut.add_theme_constant_override("outline_size", 10)
	_tut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_tut)


func _refresh_hud() -> void:
	if Game.state == null:
		return
	_hint_btn.visible = Hints.mode(Game.state) != "none"
	var nb := int(Game.state.news.get("notebook", 0))
	var bag := int(Game.state.news.get("bag", 0))
	_nb_btn.text = Game.t("hud.notebook") + (" •%d" % nb if nb > 0 else "")
	_bag_btn.text = "%s %d" % [Game.t("hud.bag"), Game.state.inventory.size()] + (" •" if bag > 0 else "")
	if _exits.size() > 0 and Game.state.vp != "":
		_set_targets(Game.state.vp)


# ------------------------------------------------------------ viewpoints

func start(play_enter_lines: bool) -> void:
	var vp_id := Game.state.vp
	if play_enter_lines:
		var lines := Interactions.enter_viewpoint(Game.state, vp_id)
		say(lines)
	else:
		Game.state.set_flag("vp." + vp_id)
	_load_vp(vp_id)
	pano.look_at_angles(Game.state.yaw, Game.state.pitch)
	_refresh_hud()
	_update_tutorial()


func _load_vp(vp_id: String) -> void:
	var vp := Game.data.viewpoint(vp_id)
	pano.set_texture(Game.data.texture("pano", vp.get("panorama", "")))
	_set_targets(vp_id)


func _set_targets(vp_id: String) -> void:
	var vp := Game.data.viewpoint(vp_id)
	var hs_list: Array = []
	for hid in vp.get("hotspots", []):
		var hs := Game.data.hotspot(hid)
		if not Interactions.hotspot_active(Game.state, hs):
			continue
		var pos: Dictionary = hs["pos"]
		hs_list.append({"id": hid, "yaw": float(pos["yaw"]), "pitch": float(pos["pitch"]), "size_deg": float(pos["size_deg"])})
	pano.hotspots = hs_list
	_exits = Interactions.exits_of(Game.state, vp_id)
	var ex_list: Array = []
	for i in _exits.size():
		var e: Dictionary = _exits[i]
		ex_list.append({"index": i, "yaw": float(e["yaw"]), "pitch": float(e.get("pitch", -22.0)), "locked": e["locked"], "icon": e.get("icon", ""), "to": e["to"]})
	pano.exits = ex_list
	var decals: Array = []
	for ov in vp.get("overlays", []):
		if ov.get("kind") == "sign":
			var sg: Dictionary = ov["sign"]
			var arr: Variant = Game.data.value_path(sg["from"], Game.state.difficulty)
			var idx := int(sg.get("index", 0))
			var sign_id: String = str(arr[idx]) if typeof(arr) == TYPE_ARRAY and idx < arr.size() else str(sg.get("missing", ""))
			decals.append({"sign": sign_id, "yaw": float(ov["yaw"]), "pitch": float(ov["pitch"]), "size_deg": float(ov["size_deg"])})
	pano.decals = decals
	pano.shimmer = Game.data.difficulty_profile(Game.state.difficulty).get("highlight") == "shimmer"
	pano.show_debug = Game.settings["debug_overlay"]


func _move_to(vp_id: String, lines: Array) -> void:
	if _busy:
		return
	_busy = true
	_tutorial_event("exit")
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE)
	await tw.finished
	var first := not Game.state.has("vp." + vp_id)
	var enter_lines := Interactions.enter_viewpoint(Game.state, vp_id)
	_load_vp(vp_id)
	if first:
		pano.look_at_angles(float(Game.data.viewpoint(vp_id).get("entry_yaw", 0)), 0.0)
	Game.state.yaw = pano.yaw
	Game.autosave()
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE)
	await tw2.finished
	_busy = false
	say(lines + enter_lines)
	Game.state_changed.emit()


# ------------------------------------------------------------ taps

func _on_tapped(p: Dictionary) -> void:
	if _busy:
		return
	var res: Dictionary
	if p["type"] == "exit":
		res = Interactions.use_exit(Game.state, _exits[p["index"]])
	elif p["type"] == "hotspot":
		_tutorial_event("hotspot")
		res = Interactions.tap_hotspot(Game.state, p["id"])
	else:
		return
	_handle(res)


func _on_long_press(p: Dictionary) -> void:
	if p["type"] != "hotspot":
		return
	var hs := Game.data.hotspot(p["id"])
	var ln: Variant = hs.get("on_first", {}).get("line", hs.get("action", {}).get("line"))
	if ln != null and Game.state.has("seen.hs." + str(p["id"])):
		say([ln])


func _handle(res: Dictionary) -> void:
	for g in res["given"]:
		_toast_given(g)
	if res.get("tutorial", "") != "":
		_toast_queue.append(Game.t(res["tutorial"]))
	match res["kind"]:
		"move":
			_move_to(res["to"], res["lines"])
		"closeup":
			var cu := CloseupScreen.new().setup(res["asset"], res["puzzle"])
			cu.open_puzzle.connect(func(pz: String) -> void:
				cu.close()
				open_puzzle(pz))
			_open(cu)
			say(res["lines"])
		"puzzle":
			say(res["lines"])
			open_puzzle(res["puzzle"])
		"document":
			_open(DocumentView.new().setup(res["doc"]))
			say(res["lines"])
		"line", "locked":
			say(res["lines"])
			if res.get("boundary_label", false) and res["lines"].size() > 0 and _is_boundary(res.get("hotspot", "")):
				_toast_queue.append(Game.t("UI-BOUNDARY"))
		"slice_end":
			say(res["lines"])
			_finish_slice()
		"slice_end_confirm":
			_confirm_end(res)
	Game.state_changed.emit()


func _is_boundary(hs_id: String) -> bool:
	return Game.data.hotspot(hs_id).get("action", {}).get("kind") == "slice_boundary"


func open_puzzle(pz: String) -> void:
	var node := Game.data.node(pz)
	var scr: Overlay
	if node.get("screen") == "code_lock":
		scr = CodeLockScreen.new().setup(pz)
	else:
		scr = StubPuzzleScreen.new().setup(pz)
	scr.solved.connect(_on_solved)
	_open(scr)


func _on_solved(pz: String) -> void:
	var given := Game.state.solve(pz)
	for g in given:
		_toast_given(g)
	var node := Game.data.node(pz)
	var lines: Array = []
	if node.get("on_solved_line") != null:
		lines.append(node["on_solved_line"])
	say(lines)
	_set_targets(Game.state.vp)
	Game.autosave()
	Game.state_changed.emit()


func _toast_given(id: String) -> void:
	var what := id
	if id.begins_with("IT-"):
		_toast_queue.append(Game.t("hud.added_bag", {"what": Game.t(Game.data.item(id).get("name_key", id))}))
		return
	if id.begins_with("CL-"):
		var c := Game.data.clue(id)
		what = Game.t(c.get("text", id), c.get("params", {}))
	elif id.begins_with("DOC-"):
		what = Game.t(Game.data.document(id).get("title", id))
	elif id.begins_with("SNAP-"):
		what = Game.t(Game.data.snapshot(id).get("title", id))
	elif id.begins_with("CODE-"):
		what = Game.t(Game.data.code(id).get("title", id))
	elif id.begins_with("Q-"):
		what = Game.t(Game.data.question(id).get("text", id))
	elif id.begins_with("GT-"):
		return
	_toast_queue.append(Game.t("hud.added_notebook", {"what": what}))
	_tutorial_event("notebook_added")


func _confirm_end(res: Dictionary) -> void:
	var ov := Overlay.new()
	ov.add_child(UiKit.dim_layer(0.6))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.paper_box())
	card.anchor_left = 0.2; card.anchor_right = 0.8; card.anchor_top = 0.2
	ov.add_child(card)
	var v := VBoxContainer.new()
	card.add_child(v)
	for ln in res["lines"]:
		Game.state.note_line(ln)
		var r := UiKit.rich(UiKit.FONT_SUB, UiKit.INK)
		r.text = "[i]%s[/i]" % UiKit.escape_bb(Game.line(ln))
		v.add_child(r)
	if not res["unseen_zones"].is_empty():
		var zones: Array = res["unseen_zones"].map(func(z: String) -> String: return Game.t("end.zone." + z))
		v.add_child(UiKit.label(Game.t("end.unseen", {"list": ", ".join(zones)}), UiKit.FONT_UI, UiKit.WALNUT))
	var row := HBoxContainer.new()
	var stay := UiKit.button(Game.t("UI-END-08"), 260)
	stay.pressed.connect(ov.close)
	row.add_child(stay)
	var enter := UiKit.button(Game.t("UI-END-07"), 300, true)
	enter.pressed.connect(func() -> void:
		ov.close()
		var end: Dictionary = Game.data.slice().get("end", {})
		say([end.get("line_on_enter")])
		_finish_slice())
	row.add_child(enter)
	v.add_child(row)
	_open(ov)


func _finish_slice() -> void:
	_busy = true
	Game.state.set_flag("ev.EV-SLICE-END")
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_fade, "color:a", 1.0, 0.6)
	await tw.finished
	Game.state.slice_ended = true
	Game.autosave()
	slice_finished.emit()


# ------------------------------------------------------------ «Мысли»

func _on_hint() -> void:
	var r := Hints.request(Game.state, Game.current_puzzle)
	match r["action"]:
		"show":
			_open(HintCard.new().setup("thought", r["lines"]))
		"wait_started":
			say(r["lines"])
			if not Game.state.has("tut.UI-TUT-08"):
				Game.state.set_flag("tut.UI-TUT-08")
				_toast_queue.append(Game.t("UI-TUT-08"))
		"busy":
			_open(HintCard.new().setup("waiting"))
		"ready":
			var card := HintCard.new().setup("ready")
			card.think.connect(func() -> void:
				var lines := Hints.open_ready(Game.state, Game.current_puzzle)
				_open(HintCard.new().setup("thought", lines))
				Game.state_changed.emit())
			_open(card)
	Game.state_changed.emit()


# ------------------------------------------------------------ overlays, subtitles, toasts

func _open(ov: Control) -> void:
	_overlays.add_child(ov)
	_overlays.mouse_filter = Control.MOUSE_FILTER_IGNORE


func has_overlay() -> bool:
	return _overlays.get_child_count() > 0


func _view_blocked() -> bool:
	for c in _overlays.get_children():
		if not (c is Overlay) or c.blocks_view:
			return true
	return false


func on_back() -> void:
	if has_overlay():
		var top := _overlays.get_child(_overlays.get_child_count() - 1)
		if top.has_method("on_back"):
			top.on_back()
		else:
			top.queue_free()
	else:
		open_pause()


func open_pause() -> void:
	var p := PauseMenu.new()
	p.main_menu.connect(func() -> void:
		Game.state.yaw = pano.yaw
		Game.state.pitch = pano.pitch
		Game.autosave()
		request_main_menu.emit())
	p.settings_changed.connect(func() -> void:
		_set_targets(Game.state.vp)
		_refresh_hud())
	_open(p)


## Shows lines as subtitles one after another (дизайн 3.5: 1.5 s + 60 ms per char, min 3 s; tap closes).
func say(lines: Array) -> void:
	for ln in lines:
		if ln != null and str(ln) != "":
			_sub_queue.append(str(ln))


func _process(delta: float) -> void:
	if Game.state == null:
		return
	Game.state.yaw = pano.yaw
	Game.state.pitch = pano.pitch
	pano.interactive = not _view_blocked() and not _busy
	# subtitles
	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			_sub_panel.visible = false
	elif not _sub_queue.is_empty():
		var id: String = _sub_queue.pop_front()
		Game.state.note_line(id)
		var ln := Game.data.line(id)
		var text := UiKit.escape_bb(Game.line(id))
		if ln.get("style") == "thought":
			_sub_text.text = "[color=#F2C98A]◔[/color] [i]%s[/i]" % text
		else:
			_sub_text.text = "[color=#F2C98A]%s:[/color] %s" % [Game.speaker_name(id), text]
		_sub_panel.visible = true
		_sub_time = maxf(3.0, 1.5 + 0.06 * Game.line(id).length())
	# toasts
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
	elif not _toast_queue.is_empty():
		_toast.text = _toast_queue.pop_front()
		_toast_time = 2.2
	else:
		_toast.text = ""
	_update_tutorial()


# ------------------------------------------------------------ tutorial (UI-TUT-01…04, 07)

func _tutorial_event(ev: String) -> void:
	if Game.state == null or Game.state.tutorial.get("done", false):
		return
	var step := int(Game.state.tutorial.get("step", 0))
	if (step == 0 and ev == "swipe") or (step == 1 and ev == "hotspot"):
		Game.state.tutorial["step"] = step + 1
	elif ev == "exit" and step >= 2:
		Game.state.tutorial["step"] = 4      # walking also ends the notebook prompt


func _update_tutorial() -> void:
	var tut: Dictionary = Game.state.tutorial
	if tut.get("done", false):
		_tut.text = ""
		return
	var step := int(tut.get("step", 0))
	if step == 2 and Game.state.has("seen.notebook"):
		tut["step"] = 3
		step = 3
	var steps: Array = Game.data.event("EV-TUTORIAL").get("steps", [])
	if step < steps.size():
		_tut.text = Game.t(steps[step])
	else:
		tut["done"] = true
		_tut.text = ""
		var then: Dictionary = Game.data.event("EV-TUTORIAL").get("then_once", {})
		if Game.state.difficulty in then.get("levels", []):
			_toast_queue.append(Game.t(then.get("ui", "UI-TUT-07")))
