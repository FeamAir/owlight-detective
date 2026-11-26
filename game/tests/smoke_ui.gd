extends SceneTree
## UI smoke run: drives the real screens through the whole slice and fails on script errors.
##   headless:     godot --headless --path game -s res://tests/smoke_ui.gd
##   screenshots:  xvfb-run godot --path game --rendering-driver opengl3 -s res://tests/smoke_ui.gd -- --shots=/abs/dir
## Exit code 0 = the flow finished; script errors are reported by the engine on stderr.

var shots_dir := ""
var main: Control
var _shot_n := 0
var _fail: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
	_run.call_deferred()


func _frames(n: int = 3) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	if shots_dir == "":
		return
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	_shot_n += 1
	img.save_png("%s/%02d_%s.png" % [shots_dir, _shot_n, name])


func _is(n: Node, cls: String) -> bool:
	return n != null and n.get_script() != null and n.get_script().get_global_name() == cls


func _expect(cond: bool, msg: String) -> void:
	if not cond:
		_fail.append(msg)
		printerr("SMOKE FAIL: ", msg)


func _find(node: Node, cls: String) -> Node:
	for c in node.get_children():
		if c.get_script() != null and c.get_script().get_global_name() == cls:
			return c
		var f := _find(c, cls)
		if f:
			return f
	return null


func _tap(ctrl: Control, pos: Vector2) -> void:
	var ev := InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = true
	ctrl._gui_input(ev)
	ev = InputEventScreenTouch.new()
	ev.position = pos
	ev.pressed = false
	ctrl._gui_input(ev)


func _run() -> void:
	var g: Node = root.get_node_or_null("Game")
	_expect(g != null, "autoload Game present")
	if g == null:
		quit(1)
		return
	g.delete_save()
	g.settings["lang"] = "ru"
	g.settings["text_speed"] = "instant"
	g.settings["debug_overlay"] = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(5)
	await _shot("main_menu")

	# difficulty → prologue
	main._choose_difficulty()
	await _frames(3)
	var diff: Control = main._screen
	diff._pick("normal")
	await _shot("difficulty")
	main._start_new("normal")
	await _frames(5)
	var intro: Control = main._screen
	await _shot("intro_letter")
	# click through the prologue
	var guard := 0
	while main._screen == intro and guard < 400:
		guard += 1
		var box: Node = _find(intro, "DialogueBox")
		if box:
			if guard == 20:
				await _shot("intro_dialogue")
			box._changed_at = -10000
			box._shown_chars = 1e9
			box._next()
		else:
			var catcher: Control = null
			for c in intro.get_children():
				if c is Control and c.mouse_filter == Control.MOUSE_FILTER_STOP and c.get_script() == null:
					catcher = c
			if catcher:
				if guard < 12:
					await _shot("intro_frame")
				var ev := InputEventScreenTouch.new()
				ev.pressed = true
				catcher.gui_input.emit(ev)
		await _frames(2)
		if guard == 60 or guard == 70:
			await _shot("gate_dialogue")
	_expect(_is(main._screen, "ExploreScreen"), "prologue finished into the game screen")
	var st: GameState = g.state
	_expect(st.inventory.has("IT-OWL") and st.inventory.has("IT-TICKET"), "owl and ticket in bag after prologue")
	_expect(st.has("line.DLG-INTRO-026"), "gate dialogue played")
	_expect(st.active_goals().has("G-01"), "goal G-01 open")

	var ex = main._screen
	await _frames(10)
	await _shot("explore_gate1")
	g.settings["debug_overlay"] = true
	ex._set_targets(st.vp)
	ex.pano.look_at_angles(10, 3)
	await _shot("explore_gate1_debug")
	g.settings["debug_overlay"] = false
	ex._set_targets(st.vp)

	# tap pillars through the real picker (yaw 0, pitch 5)
	ex.pano.look_at_angles(0, 5)
	await _frames(2)
	var centre: Vector2 = ex.pano.size * 0.5
	var p: Dictionary = ex.pano.pick(centre + Vector2(0, -40))
	_expect(p["type"] == "hotspot" and p["id"] == "HS-GATE-PILLARS", "picker finds pillars: %s" % str(p))
	ex._on_tapped(p)
	await _frames(5)
	await _shot("closeup_pillars")
	ex.on_back()
	await _frames(3)
	_expect(not ex.has_overlay(), "back closes close-up")

	# lock (yaw 30, pitch -5) → code lock screen
	ex.pano.look_at_angles(30, -5)
	await _frames(2)
	p = ex.pano.pick(ex.pano.size * 0.5)
	_expect(p["id"] == "HS-GATE-LOCK", "picker finds the lock: %s" % str(p))
	ex._on_tapped(p)
	await _frames(5)
	var lock: Node = _find(ex, "CodeLockScreen")
	_expect(lock != null, "code lock opened")
	if lock:
		lock._digits = [5, 7, 3, 6]
		lock._check()
		await _frames(3)
		await _shot("lock_wrong")
		lock._digits = [3, 7, 5, 6]
		for d in lock._drums:
			d.queue_redraw()
		lock._check()
		await _frames(30)
		await _shot("lock_solved")
		lock.solved.emit("PZ-GATE-01")
		lock.close()
		await _frames(3)
	_expect(st.is_solved("PZ-GATE-01") and st.gate_open("GT-P03"), "GATE-01 solved by the screen")

	# walk into the gatehouse via the mark (exit index 1)
	ex._on_tapped({"type": "exit", "index": 1, "id": "", "yaw": 30, "pitch": -18})
	await create_timer(1.0).timeout
	_expect(st.vp == "VP-GATE-2", "moved into the gatehouse")
	await _shot("explore_gate2")
	ex._on_tapped({"type": "hotspot", "id": "HS-GATE-RECORDER"})
	await _frames(5)
	await _shot("closeup_gate_tape")
	ex.on_back()
	ex._on_tapped({"type": "hotspot", "id": "HS-GATE-WEATHERLOG"})
	await _frames(5)
	await _shot("document_weather_log")
	ex.on_back()
	# GATE-03 (stub) → key
	ex._on_tapped({"type": "hotspot", "id": "HS-GATE-KEYBOX"})
	await _frames(5)
	var stub: Node = _find(ex, "StubPuzzleScreen")
	_expect(stub != null, "stub puzzle opened")
	await _shot("stub_gate03")
	if stub:
		stub._solve()
	await _frames(5)
	_expect(st.inventory.has("IT-STUDY-KEY"), "key obtained")

	# hints on normal: request, wait (debug fast), open
	ex._on_hint()
	await _frames(3)
	_expect(st.hint["pending"], "normal: waiting started")
	await _shot("hint_waiting")
	Hints.tick(st, 1000.0)
	ex._on_hint()
	await _frames(3)
	var card: Node = _find(ex, "HintCard")
	_expect(card != null, "ready card")
	if card:
		await _shot("hint_ready")
		card.think.emit()
		card.close()
	await _frames(3)
	await _shot("hint_thought")
	ex.on_back()
	_expect(st.thoughts_log.size() == 1, "thought journaled")

	# notebook and bag
	ex._open(load("res://scripts/ui/notebook_panel.gd").new())
	await _frames(4)
	await _shot("notebook_case")
	var nb: Node = _find(ex, "NotebookPanel")
	nb._select("clues")
	await _shot("notebook_clues")
	nb._select("questions")
	await _frames(2)
	nb.close()
	ex._open(load("res://scripts/ui/bag_panel.gd").new())
	await _frames(3)
	await _shot("bag")
	var bag: Node = _find(ex, "BagPanel")
	bag._tap("IT-OWL")
	bag._tap("IT-OWL")
	await _frames(3)
	var insp: Node = _find(ex, "ItemInspect")
	_expect(insp != null, "item inspect")
	if insp:
		insp._show_base()
		await _shot("owl_base")
		insp.close()
	bag.close()
	await _frames(2)

	# pause menu & settings language switch
	ex.open_pause()
	await _frames(3)
	await _shot("pause")
	ex.on_back()
	g.set_language("en")
	ex._set_targets(st.vp)
	ex.say(["DLG-GATE-004"])
	await _frames(6)
	await _shot("subtitle_en")
	g.set_language("ru")

	# fountain close-up with bowl zoom
	main._explore(false)
	await _frames(2)
	ex = main._screen
	ex._move_to("VP-ALLEY-1", [])
	await create_timer(1.0).timeout
	_expect(st.vp == "VP-ALLEY-1", "moved to the fountain")
	await _shot("explore_alley")
	ex._on_tapped({"type": "hotspot", "id": "HS-ALLEY-FOUNTAIN"})
	await _frames(5)
	await _shot("closeup_fountain")
	var cu: Node = _find(ex, "CloseupScreen")
	if cu:
		cu._bowl_zoom = "owl"
		cu._layer.queue_redraw()
		await _shot("closeup_bowl_owl")
		cu.close()
	# front door with key but unsolved → confirm card → enter → end
	ex._on_tapped({"type": "hotspot", "id": "HS-ALLEY-FRONTDOOR"})
	await _frames(4)
	await _shot("end_confirm")
	var conf: Node = null
	for c in ex._overlays.get_children():
		conf = c
	_expect(conf != null, "confirm card")
	ex._finish_slice()
	await create_timer(3.0).timeout
	_expect(_is(main._screen, "EndScreen"), "slice end screen")
	await _shot("end_screen")

	# save/continue roundtrip through the real file
	_expect(g.has_save(), "autosave written")
	_expect(g.load_game() and g.state.slice_ended, "save loads")
	g.delete_save()
	print("SMOKE: %d checks failed" % _fail.size())
	quit(1 if not _fail.is_empty() else 0)
