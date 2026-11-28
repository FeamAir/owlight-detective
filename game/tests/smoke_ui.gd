extends SceneTree
## UI smoke run: drives the real screens through the whole slice and fails on script errors.
##   headless:     godot --headless --path game -s res://tests/smoke_ui.gd
##   screenshots:  xvfb-run godot --path game --rendering-driver opengl3 -s res://tests/smoke_ui.gd -- --shots=/abs/dir
## Exit code 0 = the flow finished; script errors are reported by the engine on stderr.

var shots_dir := ""
var main: Control
var _shot_n := 0
var _next_n := 0
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
	# «Открыто»: a real tap on an empty spot (not the button) continues, like «Дальше ›» (owner 28.11)
	await create_timer(0.32).timeout
	_next_n += 1
	var p: Vector2 = _screen_points()[[5, 0, 7, 1, 2][_next_n % 5]]   # top edge, corners, left edge — no buttons there
	await _real_tap(p)
	await _frames(5)
	_expect(not is_instance_valid(scr) or scr.is_queued_for_deletion() or not scr.is_inside_tree(), "solved puzzle: a tap at %s continues" % p)


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


## Taps the transition mark leading to `to` through the real picker (on its screen position) and waits.
func _walk(ex: Node, to: String) -> void:
	var mark: Dictionary = {}
	for e in ex.pano.exits:
		if e["to"] == to:
			mark = e
	_expect(not mark.is_empty(), "mark to %s at %s" % [to, _g.state.vp])
	if mark.is_empty():
		return
	ex.pano.look_at_angles(float(mark["yaw"]), clampf(float(mark["pitch"]) + 8.0, -40.0, 40.0))
	await _frames(2)
	var sp: Dictionary = ex.pano.screen_pos(float(mark["yaw"]), float(mark["pitch"]))
	var pk: Dictionary = ex.pano.pick(sp["pos"] + Vector2(0, 40))      # on the label plate under the mark
	_expect(pk["type"] == "exit" and ex._exits[pk["index"]]["to"] == to, "label of the mark to %s is tappable: %s" % [to, str(pk)])
	ex._on_tapped(pk)
	await create_timer(1.0).timeout
	_expect(_g.state.vp == to, "walked to " + to)


## A tap during the short guard after a frame/line appears is not lost: it continues once the guard ends (≤ 0.3 s).
func _check_guard_taps() -> void:
	var tc: Control = load("res://scripts/ui/tap_catcher.gd").new()
	root.add_child(tc)
	await process_frame
	_expect(tc.guard <= 0.3, "tap guard ≤ 0.3 s")
	await _real_tap(root.get_visible_rect().size * 0.5)
	_expect(not tc.is_done(), "tap during the guard waits for the guard")
	await create_timer(0.35).timeout
	_expect(tc.is_done(), "tap during the guard is not lost")
	tc.queue_free()
	var box: Control = load("res://scripts/ui/dialogue_box.gd").new()
	root.add_child(box)
	box.play(["DLG-INTRO-003", "DLG-INTRO-004"], "frame")
	box._shown_chars = 1e9
	await _real_tap(Vector2(10, 10))
	_expect(box._i == 0, "dialogue: tap during the guard waits")
	await create_timer(0.3).timeout
	await _frames(2)
	_expect(box._i == 1, "dialogue: tap during the guard is not lost (line %d)" % box._i)
	box.queue_free()
	await _frames(2)


## Centre, four corners, four edge midpoints of the screen (a few px inside).
func _screen_points() -> Array:
	var sz: Vector2 = root.get_visible_rect().size
	var m := 6.0
	return [sz * 0.5, Vector2(m, m), Vector2(sz.x - m, m), Vector2(m, sz.y - m), Vector2(sz.x - m, sz.y - m),
		Vector2(sz.x * 0.5, m), Vector2(sz.x * 0.5, sz.y - m), Vector2(m, sz.y * 0.5), Vector2(sz.x - m, sz.y * 0.5)]


## Control the GUI routes a touch at `p` to (same hit test as for touches).
func _hover(p: Vector2) -> Control:
	var mm := InputEventMouseMotion.new()
	mm.position = p
	mm.global_position = p
	root.push_input(mm, true)
	return root.gui_get_hovered_control()


## A real tap through the viewport, in the Android order: emulated mouse button, then the screen touch.
func _real_tap(p: Vector2) -> void:
	for pressed in [true, false]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = pressed
		mb.position = p
		mb.global_position = p
		root.push_input(mb, true)
		var st := InputEventScreenTouch.new()
		st.position = p
		st.pressed = pressed
		root.push_input(st, true)
		await process_frame


func _intro_sig(intro: Node) -> String:
	var box: Node = _find(intro, "DialogueBox")
	return "%s/%s/%d" % [intro.frame_id, str(box.get_instance_id()) if box else "-", box._i if box else -1]


func _look(ex: Node, name: String, yaws: Array, pitch: float = 0.0) -> void:
	ex._sub_queue.clear()         # subtitles of the arrival lines would cover the view in the pictures
	ex._sub_time = 0.001
	for y in yaws:
		ex.pano.look_at_angles(float(y), pitch)
		ex.pano.reset_marks()
		await _frames(3)
		await _shot("nav_%s_yaw%03d" % [name, int(y)])


## Navigation tour (owner 27.11): every panorama in several directions, marks with labels, place captions,
## the zone map (button and notebook tab) and fast travel from it.
func _tour() -> void:
	var g := _g
	g.new_game_at("normal", {"vp": "VP-GATE-1"})
	main._explore(false)
	await _frames(5)
	var ex: Node = main._screen
	ex._show_place("VP-GATE-1")
	await _frames(10)
	_expect(ex.place_caption() == g.t("vp.VP-GATE-1"), "place caption on entering: " + ex.place_caption())
	await _shot("nav_gate1_caption")
	var gate_mark: Dictionary = ex.pano.exits[1]
	_expect(gate_mark["label"] == g.t("exit.gatehouse") and gate_mark["locked"], "gatehouse mark: label and lock")
	_expect(ex.pano.exits[0]["fresh"], "unvisited target → mark glows")
	await _look(ex, "gate1", [0, 33, 120, 180, 270])
	await _walk(ex, "VP-ALLEY-1")
	await _shot("nav_alley1_arrived")
	await _look(ex, "alley1", [0, 60, 180, 270])
	await _walk(ex, "VP-PATH-1")
	await _look(ex, "path1", [0, 90, 200])
	await _walk(ex, "VP-PIER-1")
	await _look(ex, "pier1", [0, 160, 300])
	# map: button on the game screen
	ex.open_map()
	await _frames(6)
	var mp: Node = _find(ex, "MapPanel")
	_expect(mp != null, "map opens from the game screen")
	if mp:
		await _shot("nav_map_pier")
		var v = mp.view
		_expect(v.vp_at(v.marker_pos("VP-GATE-1")) == "VP-GATE-1", "visited gate is tappable on the map")
		_expect(v.vp_at(v.marker_pos("VP-GATE-2")) == "", "not visited gatehouse is not a travel target")
		_expect("VP-GATE-2" in v.known(), "gatehouse known (a mark leads there)")
		var ev := InputEventScreenTouch.new()
		ev.position = v.marker_pos("VP-GATE-1")
		ev.pressed = false
		v._gui_input(ev)
		await create_timer(1.0).timeout
		_expect(g.state.vp == "VP-GATE-1" and not ex.has_overlay(), "fast travel from the map to the gate")
		await _shot("nav_after_travel_gate1")
	# notebook → map tab
	ex.open_notebook()
	await _frames(4)
	var nb: Node = _find(ex, "NotebookPanel")
	if nb:
		nb._select("map")
		await _frames(6)
		await _shot("nav_notebook_map")
		_expect(nb.map_view != null and nb.map_view.vp_at(nb.map_view.marker_pos("VP-PIER-1")) == "VP-PIER-1", "notebook map: pier visited")
		nb.close()
		await _frames(2)
	# gatehouse inside, hard: the wall clock is drawn by the game where the hotspot is
	g.new_game_at("hard", {"vp": "VP-GATE-2", "solved": ["PZ-GATE-01"]})
	main._explore(false)
	await _frames(5)
	ex = main._screen
	var wc := false
	for dc in ex.pano.decals:
		wc = wc or dc.get("kind") == "wallclock"
	_expect(wc, "hard: wall clock overlay in the gatehouse")
	await _look(ex, "gate2_hard", [0, 60, 180, 300])


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
	# click through the prologue with REAL input (owner 28.11: П-2 did not react on the phone). Every tap goes
	# through the viewport GUI in the Android order — emulated mouse button first, then the screen touch — and
	# on every frame/line a tap in the centre, the corners and on the edges must land on the "continue" layer
	# (not on a dead or covering node); the actual tap point cycles through those positions.
	var guard := 0
	var seen_frames := {}
	var hinted := false
	var no_target := 0
	while main._screen == intro and guard < 200:
		guard += 1
		var sig := _intro_sig(intro)
		var box: Node = _find(intro, "DialogueBox")
		var target: Control = box if box else _find(intro, "TapCatcher")
		if target == null:
			# only between frames (e.g. the 0.6 s un-blur after the gate dialogue) — never a frame waiting for a tap
			no_target += 1
			_expect(no_target < 20, "prologue %s: a tap target is on screen" % sig)
			if no_target >= 20:
				break
			await create_timer(0.1).timeout
			continue
		no_target = 0
		seen_frames[intro.frame_id] = true
		if box == null and not hinted:
			var hint: Node = target.hint
			_expect(hint != null and hint.is_visible_in_tree() and hint.text() == g.t("ui.tap_continue"), "frame %s: «tap to continue» hint" % intro.frame_id)
			await create_timer(float(hint.PULSE_AFTER) + 0.2).timeout
			_expect(hint.pulsing(), "frame %s: the hint pulses when the player waits" % intro.frame_id)
			await _shot("intro_frame_hint")
			hinted = true
		for p in _screen_points():
			var hov := _hover(p)
			var ok: bool = hov != null and (hov == target or target.is_ancestor_of(hov) or hov is Button)
			_expect(ok, "prologue %s: a tap at %s reaches the continue layer (got %s)" % [sig, p, hov])
		if box and guard == 20:
			await _shot("intro_dialogue")
		if box:
			box._shown_chars = 1e9          # the line is fully shown: the tap goes to the next one
		await _real_tap(_screen_points()[guard % 9])
		if guard % 4 == 0:
			# the guard (≤ 0.3 s): an early tap is not lost, it continues right after the guard
			await _frames(2)
		else:
			await create_timer(0.32).timeout
		await _frames(2)
		_expect(main._screen != intro or _intro_sig(intro) != sig, "prologue %s: a tap at %s continues" % [sig, _screen_points()[(guard) % 9]])
		if guard == 60 or guard == 70:
			await _shot("gate_dialogue")
	for f in ["F1", "F2", "F3", "F4", "F5", "F6", "GATE-DIALOG"]:
		_expect(seen_frames.has(f), "prologue frame %s shown and tapped through" % f)
	await _check_guard_taps()
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

	# lock → code lock screen (angles from the data = from the 3D blockout)
	var lock_pos: Dictionary = _g.data.hotspot("HS-GATE-LOCK")["pos"]
	ex.pano.look_at_angles(float(lock_pos["yaw"]), float(lock_pos["pitch"]))
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
	await _tour()
	g.delete_save()
	print("SMOKE: %d checks failed" % _fail.size())
	quit(1 if not _fail.is_empty() else 0)
