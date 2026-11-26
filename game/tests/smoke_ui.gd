extends SceneTree
## UI smoke run: drives the real screens through the whole slice and fails on script errors.
##   headless:     godot --headless --path game -s res://tests/smoke_ui.gd
##   screenshots:  xvfb-run godot --path game --rendering-driver opengl3 -s res://tests/smoke_ui.gd -- --shots=/abs/dir
## Exit code 0 = the flow finished; script errors are reported by the engine on stderr.

var shots_dir := ""
var main: Control
var _shot_n := 0
var _fail: Array = []
var _g: Node


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


## Presses "Next ›" on a solved puzzle screen (the real button) and waits.
func _next(scr: Node) -> void:
	_expect(scr._done and scr._action != null and scr._action.visible, "%s: Next button after solving" % scr.pz)
	_expect(scr.card_visible() and scr.card_layout()["fits"], "%s: solved card fits on screen %s" % [scr.pz, str(scr.card_layout())])
	scr._action.pressed.emit()
	await _frames(5)


func _move(ex: Node, vp: String) -> void:
	ex._move_to(vp, [])
	await create_timer(1.0).timeout
	_expect(_g.state.vp == vp, "moved to " + vp)


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
	_g = g
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
		var body: Label = lock._card_body
		_expect(body.text.ends_with("пяти и шести."), "lock: logic line complete: " + body.text)
		await _next(lock)
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
	# GATE-03 (T19): clock lock — wrong (departure) then 09:40
	ex._on_tapped({"type": "hotspot", "id": "HS-GATE-KEYBOX"})
	await _frames(5)
	var clock: Node = _find(ex, "ClockLockScreen")
	_expect(clock != null, "clock lock opened")
	if clock:
		await _shot("gate03_open")
		clock.set_time(ClockLockLogic.to_min("06:55"))
		clock._check()
		await _frames(3)
		_expect(st.has("line.FB-GATE03-N1"), "GATE-03 normal: departure → N1")
		await _shot("gate03_wrong")
		clock.set_time(ClockLockLogic.to_min("09:40"))
		clock._check()
		await _frames(40)
		await _shot("gate03_solved")
		await _next(clock)
	_expect(st.inventory.has("IT-STUDY-KEY") and not st.inventory.has("IT-TICKET"), "key obtained, ticket → documents")
	_expect(st.documents.has("DOC-TICKET"), "DOC-TICKET in documents")

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

	main._explore(false)
	await _frames(2)
	ex = main._screen

	# debug visuals are off in a non-debug build even if the setting was left on
	var was_debug: bool = g.debug_build
	g.debug_build = false
	g.settings["debug_overlay"] = true
	ex._set_targets(st.vp)
	_expect(not ex.pano.show_debug, "release build: no hotspot outlines / HS-IDs")
	g.debug_build = was_debug
	g.settings["debug_overlay"] = false
	ex._set_targets(st.vp)

	# PIER-01 (T08): search on the pier — a look-alike, then every target
	await _move(ex, "VP-PIER-1")
	ex._on_tapped({"type": "hotspot", "id": "HS-PIER-SCENE"})
	await _frames(5)
	var search: Node = _find(ex, "SearchScreen")
	_expect(search != null, "search screen opened")
	if search:
		await _shot("pier01_open")
		var lay: Dictionary = _g.data.layout("PZ-PIER-01")
		var zone_c := func(id: String) -> Vector2:
			for o in lay["objects"]:
				if o["id"] == id:
					return Vector2(o["rect"][0] + o["rect"][2] * 0.5, o["rect"][1] + o["rect"][3] * 0.5)
			return Vector2.ZERO
		search.tap_at(zone_c.call("lifebuoy"))
		await _frames(3)
		_expect(st.has("line.FB-PIER01-N1"), "PIER-01 normal: look-alike → «Не то»")
		for id in ["coat", "hat", "coat_hem", "puddle", "leaf_2"]:
			_expect(search.tap_at(zone_c.call(id))["kind"] == "found", "PIER-01 found " + id)
		await _frames(3)
		await _shot("pier01_progress")
		search.tap_at(zone_c.call("bucket"))
		await _frames(30)
		await _shot("pier01_solved")
		await _next(search)
	_expect(st.is_solved("PZ-PIER-01") and st.documents.has("DOC-PIER-NOTES") and st.clues.has("CL-COAT-DRY"), "PIER-01 solved: notes + clues")

	# ALLEY-01 (T16): tracks — wrong directions, then right
	await _move(ex, "VP-ALLEY-1")
	ex._on_tapped({"type": "hotspot", "id": "HS-ALLEY-GRAVEL"})
	await _frames(5)
	var tracks: Node = _find(ex, "TracksScreen")
	_expect(tracks != null, "tracks screen opened")
	if tracks:
		await _shot("alley01_open")
		for cid in ["A", "B"]:
			for pr in tracks._lay["prints"]:
				if pr["group"] == cid:
					_expect(tracks.tap_design(pr["pos"]) == cid, "tap marks chain " + cid)
					break
		tracks._toggle_dir("A")
		tracks._toggle_dir("B")       # B → to the lake: wrong
		tracks._check()
		await _frames(3)
		_expect(tracks.card_visible() and tracks._card_title.text.contains("1"), "ALLEY-01 normal: «Верно 1 из 2»")
		await _shot("alley01_wrong")
		tracks._toggle_dir("B")
		tracks._check()
		await _frames(30)
		await _shot("alley01_solved")
		await _next(tracks)
	_expect(st.is_solved("PZ-ALLEY-01") and st.clues.has("CL-PRINTS"), "ALLEY-01 solved")

	# GATE-02 (T15): compare documents from the weather recorder close-up
	await _move(ex, "VP-GATE-2")
	ex._on_tapped({"type": "hotspot", "id": "HS-GATE-WEATHERREC"})
	await _frames(5)
	var cu2: Node = _find(ex, "CloseupScreen")
	_expect(cu2 != null and cu2.puzzle == "PZ-GATE-02", "weather recorder offers «compare»")
	if cu2:
		cu2.open_puzzle.emit("PZ-GATE-02")
		await _frames(5)
	var cmp: Node = _find(ex, "CompareScreen")
	_expect(cmp != null, "compare screen opened")
	if cmp:
		await _shot("gate02_open")
		_expect(cmp.tap_tape_hour(CompareLogic.tape_hour("12 Oct 15:00")) == "r12", "tape: rain of the 12th")
		cmp.toggle("top_dry")
		cmp._pick_conclusion("D")
		await _frames(3)
		await _shot("gate02_selected")
		cmp._check()
		await _frames(3)
		_expect(cmp._card_title.text.contains("2"), "GATE-02 normal: «Верно 2 из 3»: " + cmp._card_title.text)
		_expect(cmp.selected.is_empty(), "normal: selection reset after a mistake")
		await _shot("gate02_wrong")
		cmp._show_doc("journal")
		cmp.tap_tape_hour(CompareLogic.tape_hour("15 Oct 01:00"))
		cmp._show_doc("notes")
		cmp.toggle("hat_dry")
		cmp._pick_conclusion("D")
		cmp._check()
		await _frames(30)
		await _shot("gate02_solved")
		await _next(cmp)
	_expect(st.is_solved("PZ-GATE-02") and st.clues.has("CL-RAIN"), "GATE-02 solved")

	# notebook «Solved»: titles, no PZ IDs
	ex._open(load("res://scripts/ui/notebook_panel.gd").new())
	await _frames(3)
	var nb2: Node = _find(ex, "NotebookPanel")
	nb2._select("solved")
	await _frames(3)
	await _shot("notebook_solved")
	var solved_text := ""
	for c in nb2._content.get_children():
		if c is Label:
			solved_text += c.text + "\n"
	_expect(not solved_text.contains("PZ-") and solved_text.contains("Ящик с ключами"), "Solved tab shows titles, not IDs")
	nb2.close()
	await _frames(2)

	# fountain close-up with bowl zoom
	await _move(ex, "VP-ALLEY-1")
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
	# front door with the key, everything solved → straight to the end (no confirm card)
	var res: Dictionary = Interactions.tap_hotspot(st, "HS-ALLEY-FRONTDOOR")
	_expect(res["kind"] == "slice_end", "all solved: the door ends the slice: " + str(res["kind"]))
	ex._handle(res)
	await create_timer(3.0).timeout
	_expect(_is(main._screen, "EndScreen"), "slice end screen")
	_expect(g.state.solved_count() == 5 and g.state.clues_found(_g.data.slice()["end"]["clues_counted"]) == 5, "5 of 5 puzzles, 5 of 5 clues")
	await _shot("end_screen")

	# save/continue roundtrip through the real file
	_expect(g.has_save(), "autosave written")
	_expect(g.load_game() and g.state.slice_ended, "save loads")
	g.delete_save()

	# easy / hard: each new puzzle screen opens, one typical mistake gets the level's reaction
	for lvl in ["easy", "hard"]:
		g.new_game_at(lvl, {"vp": "VP-GATE-2", "solved": ["PZ-GATE-01", "PZ-PIER-01"]})
		main._explore(false)
		await _frames(3)
		var ex2: Node = main._screen
		for pz in ["PZ-GATE-03", "PZ-PIER-01", "PZ-ALLEY-01", "PZ-GATE-02"]:
			ex2.open_puzzle(pz)
			await _frames(4)
			var scr: Node = ex2._overlays.get_child(ex2._overlays.get_child_count() - 1)
			match pz:
				"PZ-GATE-03":
					scr.set_time(ClockLockLogic.to_min("07:40" if lvl == "easy" else "10:35"))
					scr._check()
				"PZ-PIER-01":
					var lay2: Dictionary = _g.data.layout(pz)
					for o in lay2["objects"]:
						if o["id"] == "feather":
							scr.tap_at(Vector2(o["rect"][0] + o["rect"][2] * 0.5, o["rect"][1] + o["rect"][3] * 0.5))
				"PZ-ALLEY-01":
					for pt in scr._lay["pits"].slice(0, 1):
						scr.tap_design(pt["pos"])
					for pr in scr._lay["prints"]:
						if pr["group"] == "A":
							scr.tap_design(pr["pos"])
							break
					scr._toggle_dir("A")
					scr._check()
				"PZ-GATE-02":
					scr.toggle("hem_damp")
					scr.tap_tape_hour(CompareLogic.tape_hour("15 Oct 01:00") if lvl == "easy" else CompareLogic.tape_hour("15 Oct 02:00"))
					scr._pick_conclusion("D")
					scr._check()
			await _frames(4)
			var expect_line := {"easy": {"PZ-GATE-03": "FB-GATE03-E1", "PZ-PIER-01": "FB-PIER01-E5", "PZ-ALLEY-01": "FB-ALLEY01-E1", "PZ-GATE-02": "FB-GATE02-E2"}}
			if lvl == "easy":
				_expect(g.state.has("line." + expect_line["easy"][pz]), "%s easy reaction %s" % [pz, expect_line["easy"][pz]])
			else:
				_expect(pz == "PZ-PIER-01" or scr._card_title.text == g.t("UI-FB-WRONG"), "%s hard: only «Неверно»" % pz)
			await _shot("%s_%s_wrong" % [pz.to_lower().replace("pz-", ""), lvl])
			scr.close()
			await _frames(2)
	g.delete_save()
	print("SMOKE: %d checks failed" % _fail.size())
	quit(1 if not _fail.is_empty() else 0)
