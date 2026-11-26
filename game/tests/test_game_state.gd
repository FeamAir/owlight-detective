extends TestCase
## Progression on data: hotspots, gates, items, questions, slice end, save/load.


func test_gate01_opens_gatehouse() -> void:
	var st := new_state("normal")
	var exits := Interactions.exits_of(st, "VP-GATE-1")
	var door: Dictionary = exits[1]
	eq(door["to"], "VP-GATE-2", "door exit")
	check(door["locked"], "gatehouse locked at start")
	var r := Interactions.use_exit(st, door)
	eq(r["kind"], "puzzle", "locked door opens the lock puzzle")
	eq(r["puzzle"], "PZ-GATE-01", "lock puzzle")
	st.solve("PZ-GATE-01")
	check(st.gate_open("GT-P03"), "GT-P03 open after solve")
	r = Interactions.use_exit(st, Interactions.exits_of(st, "VP-GATE-1")[1])
	eq(r["kind"], "move", "door now walks")
	r = Interactions.tap_hotspot(st, "HS-GATE-LOCK")
	eq(r["kind"], "move", "lock after solve = transition")
	eq(r["to"], "VP-GATE-2", "into gatehouse")


func test_easy_autonotes_sources_not_code() -> void:
	var st := new_state("easy")
	var r := Interactions.tap_hotspot(st, "HS-GATE-PILLARS")
	eq(r["kind"], "closeup", "pillars closeup")
	check(r["lines"].has("DLG-GATE-001"), "first look line")
	check(st.codes.has("CODE-PILLARS-ORDER"), "easy: pillar order auto-noted")
	check(st.snapshots.has("SNAP-PILLARS"), "easy: pillar snapshot")
	check(st.has("seen.pillars"), "seen flag")
	var r2 := Interactions.tap_hotspot(st, "HS-GATE-PILLARS")
	eq(r2["lines"], [], "line only on first look")
	var stn := new_state("normal")
	Interactions.tap_hotspot(stn, "HS-GATE-PILLARS")
	check(stn.codes.is_empty(), "normal: no auto codes")


func test_gravel_depends_on_pier() -> void:
	var st := new_state("normal")
	var r := Interactions.tap_hotspot(st, "HS-ALLEY-GRAVEL")
	eq(r["kind"], "line", "before PIER-01: only a line")
	check(r["lines"].has("DLG-ALLEY-009"), "DLG-ALLEY-009")
	st.solve("PZ-PIER-01")
	r = Interactions.tap_hotspot(st, "HS-ALLEY-GRAVEL")
	eq(r["kind"], "puzzle", "after PIER-01: puzzle")
	eq(r["puzzle"], "PZ-ALLEY-01", "ALLEY-01")


func test_weather_recorder_states() -> void:
	var st := new_state("normal")
	var r := Interactions.tap_hotspot(st, "HS-GATE-WEATHERREC")
	check(r["lines"].has("DLG-GATE-006"), "before pier: 006")
	eq(r["puzzle"], "", "no compare mode yet")
	check(st.snapshots.has("SNAP-WEATHER-TAPE"), "tape snapshot on all levels")
	st.solve("PZ-PIER-01")
	r = Interactions.tap_hotspot(st, "HS-GATE-WEATHERREC")
	check(r["lines"].has("DLG-GATE-010"), "after pier: 010")
	eq(r["puzzle"], "PZ-GATE-02", "opens GATE-02")
	st.note_line("DLG-GATE-010")
	r = Interactions.tap_hotspot(st, "HS-GATE-WEATHERREC")
	check(not r["lines"].has("DLG-GATE-010"), "010 only once")


func test_gate03_consumes_ticket_gives_key() -> void:
	var st := new_state("normal")
	check(st.inventory.has("IT-TICKET"), "ticket at start")
	check(not st.requirements_met(data.node("PZ-GATE-03")), "GATE-03 needs the gatehouse")
	st.solve("PZ-GATE-01")
	check(st.requirements_met(data.node("PZ-GATE-03")), "GATE-03 available")
	var given := st.solve("PZ-GATE-03")
	check(st.inventory.has("IT-STUDY-KEY"), "key in bag")
	check(not st.inventory.has("IT-TICKET"), "ticket left the bag")
	check(st.documents.has("DOC-TICKET"), "ticket → documents")
	check(given.has("IT-STUDY-KEY") and given.has("DOC-TICKET"), "given list")
	check(st.has("has.IT-STUDY-KEY"), "has.* flag")


func test_recorder_is_long_link_source() -> void:
	for lvl in GameData.LEVELS:
		var st := new_state(lvl)
		Interactions.tap_hotspot(st, "HS-GATE-RECORDER")
		check(st.clues.has("CL-GATE-2310"), "clue on " + lvl)
		check(st.snapshots.has("SNAP-GATE-TAPE"), "LL-5 snapshot on all levels: " + lvl)
		eq(st.questions.has("Q-GATE-2310"), lvl != "hard", "question only easy/normal: " + lvl)


func test_wall_clock_only_on_hard() -> void:
	var st := new_state("normal")
	eq(Interactions.tap_hotspot(st, "HS-GATE-WALLCLOCK")["kind"], "none", "no wall clock on normal")
	var sth := new_state("hard")
	eq(Interactions.tap_hotspot(sth, "HS-GATE-WALLCLOCK")["kind"], "line", "wall clock on hard")


func test_questions_by_level() -> void:
	var sth := new_state("hard")
	Interactions.tap_hotspot(sth, "HS-ALLEY-BARREL")
	Interactions.tap_hotspot(sth, "HS-ALLEY-TOWERDOOR")
	check(not sth.questions.has("Q-BARREL"), "hard: no barrel question")
	check(sth.questions.has("Q-TOWER"), "hard: locked tower question")
	var ste := new_state("easy")
	Interactions.tap_hotspot(ste, "HS-ALLEY-BARREL")
	check(ste.questions.has("Q-BARREL"), "easy: barrel question")


func test_goals_flow() -> void:
	var st := new_state("normal")
	eq(st.active_goals(), [], "no goals before the gate dialogue")
	st.note_line("DLG-INTRO-028")
	st.note_line("DLG-INTRO-026")
	eq(st.active_goals(), ["G-01", "S-01"], "after prologue")
	Interactions.enter_viewpoint(st, "VP-GATE-2")
	eq(st.active_goals()[0], "G-02", "in the gatehouse")
	st.solve("PZ-PIER-01")
	check(st.active_goals().has("S-02") and st.active_goals().has("S-03"), "pier opens S-02/S-03")
	st.solve("PZ-GATE-01")
	st.solve("PZ-GATE-03")
	eq(st.active_goals()[0], "G-03", "key → open the study")


func test_front_door_and_slice_end() -> void:
	var st := new_state("easy")
	var r := Interactions.tap_hotspot(st, "HS-ALLEY-FRONTDOOR")
	eq(r["kind"], "locked", "no key: boundary")
	check(r["lines"].has("DLG-ALLEY-005"), "no key line")
	st.solve("PZ-GATE-01")
	st.solve("PZ-GATE-03")
	r = Interactions.tap_hotspot(st, "HS-ALLEY-FRONTDOOR")
	eq(r["kind"], "slice_end_confirm", "key but unsolved → confirm card")
	check(r["lines"].has("DLG-ALLEY-007"), "007")
	eq(r["unseen_zones"], ["LOC-PIER", "LOC-ALLEY", "LOC-GATE"], "easy lists zones")
	var sth := new_state("hard")
	sth.solve("PZ-GATE-01")
	sth.solve("PZ-GATE-03")
	eq(Interactions.tap_hotspot(sth, "HS-ALLEY-FRONTDOOR")["unseen_zones"], [], "hard: no list")
	for pz in ["PZ-PIER-01", "PZ-ALLEY-01", "PZ-GATE-02"]:
		st.solve(pz)
	r = Interactions.tap_hotspot(st, "HS-ALLEY-FRONTDOOR")
	eq(r["kind"], "slice_end", "all solved → end")
	check(r["lines"].has("DLG-ALLEY-006"), "006")
	eq(st.solved_count(), 5, "5 of 5")


func test_enter_viewpoint_lines() -> void:
	var st := new_state("normal")
	eq(Interactions.enter_viewpoint(st, "VP-ALLEY-1"), ["DLG-ALLEY-001"], "first entry")
	eq(Interactions.enter_viewpoint(st, "VP-ALLEY-1"), [], "second entry silent")
	st.solve("PZ-PIER-01")
	eq(Interactions.enter_viewpoint(st, "VP-ALLEY-1"), ["DLG-ALLEY-010"], "return after pier")
	eq(Interactions.enter_viewpoint(st, "VP-ALLEY-1"), [], "once")
	var ex: Dictionary = Interactions.exits_of(st, "VP-ALLEY-1")[1]
	check(Interactions.use_exit(st, ex)["lines"].has("DLG-ALLEY-011"), "first descent line")


func test_save_roundtrip() -> void:
	var st := new_state("hard")
	Interactions.tap_hotspot(st, "HS-GATE-RECORDER")
	st.solve("PZ-GATE-01")
	st.vp = "VP-GATE-2"
	st.yaw = 123.5
	st.record_attempt("PZ-GATE-01", false)
	st.hint["pending"] = true
	st.hint["remaining"] = 42.0
	var json := JSON.stringify(st.to_dict())
	var st2 := GameState.new(data)
	eq(st2.from_dict(JSON.parse_string(json)), "", "load ok")
	eq(st2.difficulty, "hard", "difficulty kept")
	check(st2.is_solved("PZ-GATE-01") and st2.gate_open("GT-P03"), "flags kept")
	eq(st2.vp, "VP-GATE-2", "position")
	near(st2.yaw, 123.5, 1e-6, "yaw")
	eq(st2.inventory, st.inventory, "bag")
	eq(st2.clues, ["CL-GATE-2310"], "clues")
	eq(st2.errors, 1, "errors")
	check(st2.hint["pending"] and is_equal_approx(float(st2.hint["remaining"]), 42.0), "hint timer survives save (hint.pending)")


func test_save_rejects_bad_versions() -> void:
	var st := GameState.new(data)
	check(st.from_dict({"version": 99}) != "", "future version rejected")
	check(st.from_dict({}) != "", "empty rejected")
	check(st.from_dict({"version": 1, "difficulty": "ultra"}) != "", "bad difficulty rejected")
