extends TestCase
## GATE-03 (T19), PIER-01 (T08), ALLEY-01 (T16), GATE-02 (T15): answer checks, reactions by level,
## logic lines. Values: values/test.yaml; cards: test-set-01 and slice-01-spec 5.2–5.5.


func _fb(pz: String, rule: String, level: String, n: int = 0, m: int = 0) -> Dictionary:
	return PuzzleRules.feedback(rule, level, data.node(pz), n, m)


# ------------------------------------------------------------ GATE-03 clock lock

func test_gate03_arrival_is_target_on_every_level() -> void:
	for lvl in GameData.LEVELS:
		var v := data.values("PZ-GATE-03", lvl)
		eq(ClockLockLogic.arrival(v), ClockLockLogic.target(v), "departure + journey = 09:40 " + lvl)
		eq(ClockLockLogic.fmt(ClockLockLogic.target(v)), "09:40", "target " + lvl)
		check(ClockLockLogic.is_correct(ClockLockLogic.to_min("21:40"), v), "21:40 = 09:40 on a 12-hour dial " + lvl)
		eq(ClockLockLogic.snap(ClockLockLogic.target(v), v), ClockLockLogic.dial(ClockLockLogic.target(v)), "target reachable with the step " + lvl)
	eq(ClockLockLogic.duration(data.values("PZ-GATE-03", "hard")), 168, "hard: 1:20 + 0:06 + 1:22")


func test_gate03_classify() -> void:
	var n := data.values("PZ-GATE-03", "normal")
	var m := func(s: String) -> int: return ClockLockLogic.to_min(s)
	eq(ClockLockLogic.classify(m.call("09:40"), n), "correct", "09:40")
	eq(ClockLockLogic.classify(m.call("06:55"), n), "departure", "departure")
	eq(ClockLockLogic.classify(m.call("02:45"), n), "duration", "journey")
	eq(ClockLockLogic.classify(m.call("09:35"), n), "near", "9:35")
	eq(ClockLockLogic.classify(m.call("09:50"), n), "near", "9:50")
	eq(ClockLockLogic.classify(m.call("08:40"), n), "near", "8:40 (an hour off)")
	eq(ClockLockLogic.classify(m.call("12:00"), n), "now", "hands untouched")
	eq(ClockLockLogic.classify(m.call("04:20"), n), "other", "random")
	var h := data.values("PZ-GATE-03", "hard")
	eq(ClockLockLogic.classify(m.call("10:35"), h), "now", "hard: wall clock")
	eq(ClockLockLogic.classify(m.call("09:15"), h), "ticket_no", "hard: ticket No 0915")
	eq(ClockLockLogic.classify(m.call("06:52"), h), "departure", "hard departure")
	var e := data.values("PZ-GATE-03", "easy")
	eq(ClockLockLogic.classify(m.call("07:40"), e), "departure", "easy departure")
	eq(ClockLockLogic.classify(m.call("02:00"), e), "duration", "easy journey")


func test_gate03_feedback_by_level() -> void:
	eq(_fb("PZ-GATE-03", "departure", "easy"), {"ui": "", "ui_params": {}, "line": "FB-GATE03-E1"}, "easy E1")
	eq(_fb("PZ-GATE-03", "duration", "easy")["line"], "FB-GATE03-E2", "easy E2")
	eq(_fb("PZ-GATE-03", "near", "easy")["line"], "FB-GATE03-E3", "easy E3")
	eq(_fb("PZ-GATE-03", "now", "easy")["line"], "FB-GATE03-E4", "easy E4")
	eq(_fb("PZ-GATE-03", "other", "easy"), {"ui": "UI-FB-WRONG", "ui_params": {}, "line": ""}, "easy other: Wrong")
	eq(_fb("PZ-GATE-03", "departure", "normal"), {"ui": "UI-FB-WRONG", "ui_params": {}, "line": "FB-GATE03-N1"}, "normal N1")
	eq(_fb("PZ-GATE-03", "near", "normal")["line"], "FB-GATE03-N2", "normal N2")
	eq(_fb("PZ-GATE-03", "duration", "normal"), {"ui": "UI-FB-WRONG", "ui_params": {}, "line": ""}, "normal journey: only Wrong")
	eq(_fb("PZ-GATE-03", "departure", "hard"), {"ui": "UI-FB-WRONG", "ui_params": {}, "line": ""}, "hard: only Wrong")


func test_gate03_hands() -> void:
	var n := data.values("PZ-GATE-03", "normal")
	var t := ClockLockLogic.to_min("09:55")
	# minute hand dragged past 12 → next hour
	eq(ClockLockLogic.fmt(ClockLockLogic.drag_minute(t, TAU * 5.0 / 60.0, n)), "10:05", "carry over 12")
	eq(ClockLockLogic.fmt(ClockLockLogic.drag_minute(ClockLockLogic.to_min("10:05"), TAU * 55.0 / 60.0, n)), "09:55", "back over 12")
	eq(ClockLockLogic.fmt(ClockLockLogic.drag_minute(t, TAU * 41.0 / 60.0, n)), "09:40", "snaps to 5 min on normal")
	eq(ClockLockLogic.fmt(ClockLockLogic.drag_hour(ClockLockLogic.to_min("12:40"), TAU * 9.0 / 12.0)), "09:40", "hour hand")
	near(ClockLockLogic.hour_angle(ClockLockLogic.to_min("03:00")), PI / 2.0, 0.001, "hour hand at 3")
	eq(ClockLockLogic.snap(ClockLockLogic.to_min("09:44"), data.values("PZ-GATE-03", "easy")), ClockLockLogic.to_min("09:40"), "easy step 10")


func test_gate03_logic_line() -> void:
	eq(PuzzleRules.logic_text("PZ-GATE-03", "normal", "ru", data), data.line_text("LOGIC-GATE-03", "ru"), "normal RU = canon")
	eq(PuzzleRules.logic_text("PZ-GATE-03", "normal", "en", data), data.line_text("LOGIC-GATE-03", "en"), "normal EN = canon")
	eq(PuzzleRules.logic_text("PZ-GATE-03", "easy", "ru", data), "Семь сорок и ещё два часа в пути — поезд пришёл в девять сорок. Тарн ждал меня.", "easy RU uses the easy ticket")
	check(not PuzzleRules.logic_text("PZ-GATE-03", "hard", "en", data).contains("{"), "hard EN filled")


# ------------------------------------------------------------ PIER-01 search

func _lay() -> Dictionary:
	return data.layout("PZ-PIER-01")


func _obj(id: String) -> Dictionary:
	for o in _lay()["objects"]:
		if o["id"] == id:
			return o
	return {}


func _centre(id: String) -> Vector2:
	var r: Array = _obj(id)["rect"]
	return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)


func test_pier01_hit_and_targets() -> void:
	eq(SearchLogic.hit(_lay(), "normal", _centre("hat"))["id"], "hat", "hat on the coat wins over the coat")
	eq(SearchLogic.hit(_lay(), "normal", _centre("coat_hem"))["id"], "coat_hem", "damp hem zone")
	eq(SearchLogic.hit(_lay(), "normal", _centre("coat"))["id"], "coat", "coat body")
	eq(SearchLogic.hit(_lay(), "normal", Vector2(0.62, 0.95))["id"], "boards", "bare boards → background")
	eq(SearchLogic.objects(_lay(), "normal").filter(func(o: Dictionary) -> bool: return o["id"] == "oilskin").size(), 0, "oilskin only on hard")
	eq(SearchLogic.objects(_lay(), "hard").filter(func(o: Dictionary) -> bool: return o["id"] == "oilskin").size(), 1, "oilskin on hard")
	eq(SearchLogic.targets(data.values("PZ-PIER-01", "easy")).size(), 4, "easy: 4 targets")
	eq(SearchLogic.targets(data.values("PZ-PIER-01", "normal")).size(), 6, "normal: 6 targets")
	eq(SearchLogic.list_kind("full_bucket", data.values("PZ-PIER-01", "hard")), "description", "hard: bucket by description")
	eq(SearchLogic.list_kind("full_bucket", data.values("PZ-PIER-01", "normal")), "silhouette", "normal: silhouette")
	check(SearchLogic.shows_counter(data.values("PZ-PIER-01", "easy")), "easy counter")
	check(not SearchLogic.shows_counter(data.values("PZ-PIER-01", "hard")), "no counter on hard")


func test_pier01_taps() -> void:
	var v := data.values("PZ-PIER-01", "easy")
	var found: Array = []
	eq(SearchLogic.tap(_obj("coat"), found, v)["kind"], "found", "coat found")
	found.append("coat")
	eq(SearchLogic.tap(_obj("coat"), found, v), {"kind": "reaction", "target": "", "rule": "whole_coat"}, "coat again while hem missing → E4")
	eq(SearchLogic.tap(_obj("lifebuoy"), found, v)["rule"], "lifebuoy", "lifebuoy → E1")
	eq(SearchLogic.tap(_obj("net_box"), found, v)["rule"], "tarp", "tarp → E3 by default")
	eq(SearchLogic.tap(_obj("net_box"), [], v, "coat")["rule"], "tarp_as_coat", "tarp while the coat silhouette is picked → E2")
	eq(SearchLogic.tap(_obj("boards"), found, v, "coat_damp_hem")["rule"], "whole_coat", "boards for the hem → E4")
	eq(SearchLogic.tap(_obj("boards"), found, v)["kind"], "none", "boards without a pick: nothing")
	eq(SearchLogic.tap(_obj("leaf_1"), found, v)["kind"], "none", "leaves are not a target on easy")
	eq(SearchLogic.tap(_obj("feather"), found, v)["rule"], "feather", "feather → E5")
	for t in ["hat", "coat_damp_hem", "puddle"]:
		found.append(t)
	eq(SearchLogic.tap(_obj("coat"), found, v)["kind"], "already", "coat again after the hem: silent")
	check(SearchLogic.is_complete(found, v), "easy complete with 4")
	check(not SearchLogic.is_complete(found, data.values("PZ-PIER-01", "normal")), "normal needs leaves and bucket")
	eq(SearchLogic.tap(_obj("leaf_3"), found, data.values("PZ-PIER-01", "normal"))["target"], "wet_leaves", "normal: leaves")


func test_pier01_feedback_by_level() -> void:
	eq(_fb("PZ-PIER-01", "lifebuoy", "easy")["line"], "FB-PIER01-E1", "easy E1")
	eq(_fb("PZ-PIER-01", "tarp_as_coat", "easy")["line"], "FB-PIER01-E2", "easy E2")
	eq(_fb("PZ-PIER-01", "tarp", "easy")["line"], "FB-PIER01-E3", "easy E3")
	eq(_fb("PZ-PIER-01", "whole_coat", "easy")["line"], "FB-PIER01-E4", "easy E4")
	eq(_fb("PZ-PIER-01", "feather", "easy")["line"], "FB-PIER01-E5", "easy E5")
	eq(_fb("PZ-PIER-01", "feather", "normal"), {"ui": "", "ui_params": {}, "line": "FB-PIER01-N1"}, "normal: «Не то» only")
	eq(_fb("PZ-PIER-01", "feather", "hard"), {"ui": "", "ui_params": {}, "line": ""}, "hard: no reaction")


# ------------------------------------------------------------ ALLEY-01 tracks

func test_alley01_layout() -> void:
	for lvl in GameData.LEVELS:
		var v := data.values("PZ-ALLEY-01", lvl)
		var lay := TracksLogic.layout(v, lvl)
		var per := {}
		for p in lay["prints"]:
			per[p["group"]] = int(per.get(p["group"], 0)) + 1
			var pos: Vector2 = p["pos"]
			check(pos.x > TracksLogic.PATH_X.x and pos.x < TracksLogic.PATH_X.y and pos.y > TracksLogic.PATH_Y.x and pos.y < TracksLogic.PATH_Y.y, "%s print inside the path %s" % [lvl, pos])
		for c in v["chains"]:
			eq(int(per.get(c["id"], 0)), int(c["prints"]), "%s chain %s prints" % [lvl, c["id"]])
		eq(lay["pits"].size(), int(v["washed_pits"]), "%s washed pits" % lvl)
		eq(lay["gull"].size() > 0, lvl == "hard", "%s gull tracks only on hard" % lvl)
		for pt in lay["pits"]:
			eq(TracksLogic.hit(lay, pt["pos"]), "pits", "%s pit is tappable" % lvl)
		for p2 in lay["prints"]:
			if TracksLogic.hit(lay, p2["pos"]) == p2["group"]:
				continue
			check(lvl == "hard", "%s print at %s taps its chain" % [lvl, p2["pos"]])
	var toe: Array = TracksLogic.layout(data.values("PZ-ALLEY-01", "hard"), "hard")["prints"].filter(func(p: Dictionary) -> bool: return p["toe_only"])
	eq(toe.size(), 3, "hard: three prints of B without a heel")
	check(toe.all(func(p: Dictionary) -> bool: return p["group"] == "B"), "toe-only prints are B")
	var lay_n := TracksLogic.layout(data.values("PZ-ALLEY-01", "normal"), "normal")
	eq(TracksLogic.hit(lay_n, Vector2(100, 650)), "ruts", "tyre ruts")
	eq(TracksLogic.hit(lay_n, Vector2(800, 560)), "trampled", "trampled by the drive")
	eq(TracksLogic.layout(data.values("PZ-ALLEY-01", "easy"), "easy"), TracksLogic.layout(data.values("PZ-ALLEY-01", "easy"), "easy"), "deterministic")


func test_alley01_check() -> void:
	var v := data.values("PZ-ALLEY-01", "normal")
	var ok := TracksLogic.check(["A", "B"], {"A": "to_pier", "B": "to_alley"}, v)
	check(ok["ok"], "A to the lake, B to the drive")
	eq(TracksLogic.check(["B", "A"], {"A": "to_pier", "B": "to_alley"}, v)["ok"], true, "order does not matter")
	var r := TracksLogic.check(["A", "B", "pits"], {"A": "to_pier", "B": "to_alley"}, v)
	eq([r["rule"], r["n"]], ["pits", 1], "pits marked")
	eq(TracksLogic.check(["A", "B", "ruts"], {"A": "to_pier", "B": "to_alley"}, v)["rule"], "ruts", "ruts")
	eq(TracksLogic.check(["A", "B", "trampled"], {"A": "to_pier", "B": "to_alley"}, v)["rule"], "trampled", "trampled")
	r = TracksLogic.check(["A"], {"A": "to_pier"}, v)
	eq([r["rule"], r["n"]], ["one_chain", 0], "one chain")
	r = TracksLogic.check(["A", "B"], {"A": "to_alley", "B": "to_pier"}, v)
	eq([r["rule"], r["n"], r["m"]], ["direction", 1, 2], "directions swapped: 1 of 2")
	eq(TracksLogic.check(["A", "B"], {"A": "to_pier"}, v)["rule"], "direction", "direction not set")
	eq(TracksLogic.check(["A", "B", "gull"], {"A": "to_pier", "B": "to_alley"}, data.values("PZ-ALLEY-01", "hard"))["rule"], "gull", "hard: gull")
	eq(TracksLogic.next_dir(""), "to_pier", "toggle from unset")
	eq(TracksLogic.next_dir("to_pier"), "to_alley", "toggle")


func test_alley01_feedback_by_level() -> void:
	eq(_fb("PZ-ALLEY-01", "pits", "easy")["line"], "FB-ALLEY01-E1", "E1")
	eq(_fb("PZ-ALLEY-01", "ruts", "easy")["line"], "FB-ALLEY01-E2", "E2")
	eq(_fb("PZ-ALLEY-01", "trampled", "easy")["line"], "FB-ALLEY01-E3", "E3")
	eq(_fb("PZ-ALLEY-01", "one_chain", "easy")["line"], "FB-ALLEY01-E4", "E4")
	eq(_fb("PZ-ALLEY-01", "direction", "easy")["line"], "FB-ALLEY01-E5", "E5")
	eq(_fb("PZ-ALLEY-01", "direction", "normal", 1, 2), {"ui": "UI-FB-COUNT", "ui_params": {"n": 1, "m": 2}, "line": ""}, "normal: N of 2")
	eq(_fb("PZ-ALLEY-01", "gull", "hard"), {"ui": "UI-FB-WRONG", "ui_params": {}, "line": ""}, "hard: Wrong")


# ------------------------------------------------------------ GATE-02 compare

func test_gate02_fragments() -> void:
	var snap := data.values("SNAP-GATE-TAPE", "hard")
	var e := CompareLogic.fragments(data.values("PZ-GATE-02", "easy"), snap)
	eq(e.size(), 2 + 5, "easy: tape (day 14, night) + 5 notes")
	eq(CompareLogic.docs(data.values("PZ-GATE-02", "easy"), snap), ["tape", "notes"], "easy: two documents")
	eq(CompareLogic.docs(data.values("PZ-GATE-02", "normal"), snap), ["tape", "notes", "journal"], "normal: three")
	eq(CompareLogic.docs(data.values("PZ-GATE-02", "hard"), snap), ["tape", "notes", "journal", "gate"], "hard: four")
	var gate_ids: Array = CompareLogic.gate_marks(snap).map(func(m: Dictionary) -> String: return m["id"])
	eq(gate_ids, ["gate_14_1730", "gate_14_2310", "gate_15_0855"], "gate tape marks incl. 08:55 (v1.2)")


func test_gate02_check() -> void:
	for lvl in GameData.LEVELS:
		var v := data.values("PZ-GATE-02", lvl)
		var rain: String = v["answer"]["rain"][0]
		check(CompareLogic.check([rain, "top_dry"], "D", v)["ok"], lvl + ": rain + top dry, D")
		check(CompareLogic.check(["hat_dry", rain], "D", v)["ok"], lvl + ": hat dry works too, any order")
		var r := CompareLogic.check([rain, "top_dry"], "C", v)
		eq([r["rule"], r["n"], r["m"]], ["wrong_conclusion", 2, 3], lvl + ": right pieces, wrong conclusion → E5, 2 of 3")
		eq(CompareLogic.check([rain, "hem_damp"], "D", v)["rule"], "hem", lvl + ": damp hem → E2")
		eq(CompareLogic.check([rain, "puddle"], "D", v)["rule"], "rain_evidence", lvl + ": puddle → E3")
		eq(CompareLogic.check([rain, "coat_folded"], "D", v)["rule"], "folded", lvl + ": folded → E4")
		eq(CompareLogic.check(["top_dry", "hat_dry"], "D", v)["rule"], "tape_wrong", lvl + ": no tape → E1")
	var e := data.values("PZ-GATE-02", "easy")
	eq(CompareLogic.check(["day14", "top_dry"], "D", e)["rule"], "tape_wrong", "easy: day of the 14th → E1")
	var keep := CompareLogic.check(["day14", "top_dry"], "D", e)
	eq([keep["keep"], keep["keep_conclusion"], keep["n"]], [["top_dry"], true, 2], "easy keeps the right parts")
	var n := data.values("PZ-GATE-02", "normal")
	eq(CompareLogic.check(["r12", "top_dry"], "D", n)["rule"], "tape_wrong", "normal: rain of the 12th")
	eq(CompareLogic.check(["j14_dry", "top_dry"], "D", n)["rule"], "journal", "normal: journal «14 Oct dry»")
	var h := data.values("PZ-GATE-02", "hard")
	check(not CompareLogic.check(["night", "top_dry"], "D", h)["ok"], "hard: 'night' alone is not a fragment")
	eq(CompareLogic.check(["night_start", "top_dry"], "D", h)["rule"], "tape_wrong", "hard: pen went up = only the start")
	eq(CompareLogic.check(["night_mid", "top_dry"], "D", h)["rule"], "tape_wrong", "hard: pen high")
	eq(CompareLogic.check(["gate_15_0855", "top_dry"], "D", h)["rule"], "decoy_doc", "hard: 08:55 trap (v1.2)")
	eq(CompareLogic.check(["j14_forecast", "top_dry"], "D", h)["rule"], "decoy_doc", "hard: forecast")
	check(CompareLogic.check(["night_end", "hat_dry"], "D", h)["ok"], "hard: pen came down + hat")
	check(not CompareLogic.can_submit(["night_end"], "D"), "Done needs two fragments")
	check(not CompareLogic.can_submit(["night_end", "top_dry"], ""), "Done needs a conclusion")


func test_gate02_tape_zones() -> void:
	var h := data.values("PZ-GATE-02", "hard")
	var zones := CompareLogic.tape_zones(h)
	var by := {}
	for z in zones:
		by[z["id"]] = z
	var px := 72.0                                # CompareScreen.PX_PER_H
	for id in ["night_start", "night_mid", "night_end", "r10", "r12"]:
		check((by[id]["to"] - by[id]["from"]) * px >= 95.0, "hard zone %s ≥ 48 dp wide" % id)
	var t_end := CompareLogic.tape_hour("15 Oct 02:00")
	eq(CompareLogic.tape_hit(zones, t_end), "night_end", "02:00 → pen came down")
	eq(CompareLogic.tape_hit(zones, CompareLogic.tape_hour("14 Oct 23:15")), "night_start", "23:15 → pen went up")
	eq(CompareLogic.tape_hit(zones, CompareLogic.tape_hour("15 Oct 00:40")), "night_mid", "middle of the night")
	eq(CompareLogic.tape_hit(zones, CompareLogic.tape_hour("13 Oct 12:00")), "", "dry day: nothing")
	eq(CompareLogic.tape_hit(CompareLogic.tape_zones(data.values("PZ-GATE-02", "easy")), CompareLogic.tape_hour("15 Oct 01:00")), "night", "easy night")


func test_gate02_feedback_and_logic() -> void:
	eq(_fb("PZ-GATE-02", "tape_wrong", "easy")["line"], "FB-GATE02-E1", "E1")
	eq(_fb("PZ-GATE-02", "hem", "easy")["line"], "FB-GATE02-E2", "E2")
	eq(_fb("PZ-GATE-02", "rain_evidence", "easy")["line"], "FB-GATE02-E3", "E3")
	eq(_fb("PZ-GATE-02", "folded", "easy")["line"], "FB-GATE02-E4", "E4")
	eq(_fb("PZ-GATE-02", "wrong_conclusion", "easy")["line"], "FB-GATE02-E5", "E5")
	eq(_fb("PZ-GATE-02", "wrong_conclusion", "normal", 2, 3), {"ui": "UI-FB-COUNT", "ui_params": {"n": 2, "m": 3}, "line": ""}, "normal: 2 of 3")
	eq(_fb("PZ-GATE-02", "decoy_doc", "hard")["ui"], "UI-FB-WRONG", "hard: Wrong")
	eq(PuzzleRules.logic_text("PZ-GATE-02", "normal", "ru", data), "Лента: ночной дождь кончился около двух. А верх пальто сухой — под дождём оно не лежало. Его принесли потом.", "LOGIC-GATE-02 RU (5.4)")
	eq(PuzzleRules.logic_text("PZ-GATE-02", "hard", "en", data), "The tape: the night rain stopped at around two. But the top of the coat is dry — it never lay out in the rain. It was brought later.", "LOGIC-GATE-02 EN")
	eq(PuzzleRules.logic_text("PZ-PIER-01", "easy", "ru", data), data.line_text("LOGIC-PIER-01", "ru"), "LOGIC-PIER-01")
	eq(PuzzleRules.logic_text("PZ-ALLEY-01", "hard", "en", data), data.line_text("LOGIC-ALLEY-01", "en"), "LOGIC-ALLEY-01")


# ------------------------------------------------------------ texts fit the card

func test_logic_lines_fit_the_card() -> void:
	# the "solved" card of a puzzle screen: 63.5 % of the width, ≤ 46 % of the height (PuzzleScreen)
	for vs in [Vector2(1600, 720), Vector2(1600, 900), Vector2(1280, 720)]:
		var width: float = vs.x * (PuzzleScreen.CARD_RIGHT - PuzzleScreen.CARD_LEFT) - PuzzleScreen.CARD_PAD.x * 2.0 - 6.0
		var max_h: float = vs.y * 0.46 - PuzzleScreen.CARD_PAD.y * 2.0 - 6.0 - 50.0
		for pz in ["PZ-GATE-01", "PZ-GATE-02", "PZ-GATE-03", "PZ-PIER-01", "PZ-ALLEY-01"]:
			for lvl in GameData.LEVELS:
				for lang in ["ru", "en"]:
					var text := PuzzleRules.logic_text(pz, lvl, lang, data)
					var sz := UiKit.fit_font_size(text, width, max_h)
					check(sz >= 26, "%s %s %s at %s: font %d" % [pz, lvl, lang, vs, sz])
					check(UiKit.text_height(text, width, sz) <= max_h, "%s %s %s fits at %s" % [pz, lvl, lang, vs])
