extends TestCase
## «Мысли»: front, stages, waiting on normal, none on hard (brief №5, №13; spec 7.3).


func test_front_at_start() -> void:
	var st := new_state("normal")
	eq(Hints.front(st), ["PZ-GATE-01", "PZ-PIER-01"], "two fronts at start (spec 2.2)")
	st.solve("PZ-GATE-01")
	eq(Hints.front(st), ["PZ-GATE-03", "PZ-PIER-01"], "after GATE-01")
	st.solve("PZ-GATE-03")
	eq(Hints.front(st), ["PZ-PIER-01", "SLICE-END"], "key: unsolved first, door last (7.3)")


func test_easy_area_then_precise_then_next() -> void:
	var st := new_state("easy")
	var r := Hints.request(st)
	eq(r["action"], "show", "instant")
	eq(r["lines"], ["HINT-EX-01"], "area 1")
	eq(Hints.request(st)["lines"], ["HINT-NAV-GATE01-P1"], "precise on second tap")
	eq(Hints.request(st)["lines"], ["HINT-NAV-PIER01-A1"], "then the next target")
	eq(st.hints_used, 3, "counted")
	eq(st.thoughts_log.size(), 3, "journal")


func test_last_touched_puzzle_first() -> void:
	var st := new_state("easy")
	st.last_puzzle = "PZ-PIER-01"
	eq(Hints.request(st)["lines"], ["HINT-NAV-PIER01-A1"], "abandoned puzzle first")


func test_ready_and_missing_on_puzzle_screen() -> void:
	var st := new_state("easy")
	eq(Hints.select(st, "PZ-GATE-01")["line"], "HINT-NAV-GATE01-M", "sources not seen → missing")
	for f in ["seen.pillars", "seen.fountain_levels", "seen.lock_engraving"]:
		st.set_flag(f)
	eq(Hints.select(st, "PZ-GATE-01")["line"], "HINT-NAV-GATE01-R", "all seen → ready")


func test_normal_waits() -> void:
	var st := new_state("normal")
	var r := Hints.request(st)
	eq(r["action"], "wait_started", "wait")
	eq(r["lines"], ["HINT-WAIT-01"], "confirmation line")
	eq(Hints.request(st)["action"], "busy", "second press while waiting")
	near(float(st.hint["remaining"]), 300.0, 1e-3, "5 minutes [ТЕСТ]")
	check(not Hints.tick(st, 299.0), "not yet")
	check(Hints.tick(st, 2.0), "ready after 5 min")
	eq(Hints.request(st)["action"], "ready", "ready card")
	eq(Hints.open_ready(st), ["HINT-EX-01"], "content chosen when opened")
	eq(Hints.request(st)["lines"], ["HINT-WAIT-02"], "next request waits again")


func test_normal_target_solved_during_wait() -> void:
	var st := new_state("normal")
	Hints.request(st)
	st.solve("PZ-GATE-01")
	Hints.tick(st, 400.0)
	var lines := Hints.open_ready(st)
	eq(lines[0], "HINT-SELF-01", "solved meanwhile → 'never mind' first")
	eq(lines[1], "HINT-EX-02", "recomputed for the new target")


func test_cancel() -> void:
	var st := new_state("normal")
	Hints.request(st)
	Hints.cancel(st)
	check(not st.hint["pending"] and not st.hint["ready"], "cancelled")
	eq(st.hints_used, 0, "cancel is free")


func test_hard_has_no_hints() -> void:
	var st := new_state("hard")
	eq(Hints.request(st)["action"], "none", "no hints on hard")


func test_hint_lines_never_name_answers() -> void:
	# The nav lines must not contain digits of codes (spec 7.3 check).
	for id in data.node_order:
		var nav: Dictionary = data.node(id).get("nav", {})
		var all: Array = nav.get("area", []) + nav.get("precise", [])
		for k in ["ready", "missing"]:
			if nav.has(k):
				all.append(nav[k])
		for ln in all:
			for lang in ["ru", "en"]:
				var t := data.line_text(ln, lang)
				for code in ["375", "3756", "2946", "09:40", "9:40"]:
					check(not t.contains(code), "%s mentions %s" % [ln, code])
