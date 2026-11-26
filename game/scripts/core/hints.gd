class_name Hints
extends RefCounted
## «Мысли» Клары — navigation hints (brief №5, №13; каркас 3.5; дизайн 3.11; spec 7.3).
## Easy: instant. Normal: request → wait (5 min [ТЕСТ]) → "ready" → content chosen at opening time.
## Hard: no button. Hints never give solutions: they only choose a line from node.nav.


static func mode(st: GameState) -> String:
	return str(st.data.difficulty_profile(st.difficulty).get("hint", {}).get("mode", "none"))


static func wait_seconds(st: GameState, precise: bool) -> float:
	var h: Dictionary = st.data.difficulty_profile(st.difficulty).get("hint", {})
	var minutes := float(h.get("precise_wait_minutes" if precise else "wait_minutes", 5))
	return minutes * 60.0


## Front of the slice graph (каркас 3.5 п.1–3), in priority order:
## the puzzle the player touched last and left → mandatory puzzles in data order → others → slice end.
static func front(st: GameState) -> Array:
	var mandatory: Array = []
	var optional: Array = []
	var tail: Array = []
	for id in st.data.node_order:
		var n := st.data.node(id)
		if n.get("kind") == "puzzle":
			if st.is_solved(id) or not st.requirements_met(n):
				continue
			if n.get("mandatory", false):
				mandatory.append(id)  # "any_of:F-I-3" is non-empty → mandatory for act I (spec 7.3)
			else:
				optional.append(id)
		elif n.get("kind") == "goal":
			if not st.slice_ended and st.requirements_met(n):
				tail.append(id)
	var out: Array = mandatory + optional + tail
	if st.last_puzzle != "" and out.has(st.last_puzzle):
		out.erase(st.last_puzzle)
		out.push_front(st.last_puzzle)
	return out


## Chooses the thought now. current_puzzle — the puzzle screen the player is on ("" if none).
## Returns {target, stage, line} (line "" when there is nothing to say).
static func select(st: GameState, current_puzzle: String = "") -> Dictionary:
	var fr := front(st)
	if current_puzzle != "" and fr.has(current_puzzle):
		var n := st.data.node(current_puzzle)
		var nav: Dictionary = n.get("nav", {})
		if st.knows_met(n):
			return {"target": current_puzzle, "stage": "ready", "line": str(nav.get("ready", ""))}
		if nav.get("missing") != null:
			return {"target": current_puzzle, "stage": "missing", "line": str(nav["missing"])}
	if fr.is_empty():
		return {"target": "", "stage": "", "line": ""}
	var target: String = fr[0]
	var stage := "area"
	if st.hint.get("last_target", "") == target:
		if st.hint.get("last_stage", "") == "area":
			stage = "precise"
		elif fr.size() > 1:
			target = fr[1]          # the same target goes to the end of the queue (каркас 3.5 п.3)
			stage = "area"
			if st.hint.get("last_target", "") == target and st.hint.get("last_stage", "") == "area":
				stage = "precise"
		else:
			stage = "precise"
	var nav2: Dictionary = st.data.node(target).get("nav", {})
	var lines: Array = nav2.get(stage, [])
	if lines.is_empty():
		lines = nav2.get("area", [])
	var key := "%s:%s" % [target, stage]
	var counts: Dictionary = st.hint.get("counts", {})
	var idx := int(counts.get(key, 0))
	var line := str(lines[idx % lines.size()]) if not lines.is_empty() else ""
	return {"target": target, "stage": stage, "line": line}


## Records that a thought was shown (journal, stats, rotation).
static func commit(st: GameState, sel: Dictionary) -> void:
	if sel.get("line", "") == "":
		return
	st.hint["last_target"] = sel["target"]
	st.hint["last_stage"] = sel["stage"]
	var key := "%s:%s" % [sel["target"], sel["stage"]]
	var counts: Dictionary = st.hint.get("counts", {})
	counts[key] = int(counts.get(key, 0)) + 1
	st.hint["counts"] = counts
	st.hints_used += 1
	st.thoughts_log.append({"line": sel["line"], "vp": st.vp})
	if sel["target"] != "" and st.data.node(sel["target"]).get("kind") == "puzzle":
		var s := st.stats_for(sel["target"])
		s["hints"] = int(s["hints"]) + 1


## Button press. Returns {action, lines}:
##   easy:   action "show", lines [thought]
##   normal: "wait_started" [HINT-WAIT-0x] | "busy" [HINT-WAIT-BUSY] | "ready" (UI shows the ready card)
##   hard:   "none"
static func request(st: GameState, current_puzzle: String = "") -> Dictionary:
	match mode(st):
		"instant":
			var sel := select(st, current_puzzle)
			commit(st, sel)
			return {"action": "show", "lines": [sel["line"]] if sel["line"] != "" else [], "sel": sel}
		"wait":
			if st.hint.get("ready", false):
				return {"action": "ready", "lines": []}
			if st.hint.get("pending", false):
				return {"action": "busy", "lines": ["HINT-WAIT-BUSY"]}
			var preview := select(st, current_puzzle)
			st.hint["pending"] = true
			st.hint["remaining"] = wait_seconds(st, preview.get("stage", "") == "precise")
			st.hint["pending_target"] = preview.get("target", "")
			var n := int(st.hint.get("requests", 0))
			st.hint["requests"] = n + 1
			return {"action": "wait_started", "lines": ["HINT-WAIT-0%d" % (n % 3 + 1)]}
	return {"action": "none", "lines": []}


## Called every frame with game time; speed > 1 is the debug acceleration.
static func tick(st: GameState, delta: float) -> bool:
	if not st.hint.get("pending", false):
		return false
	st.hint["remaining"] = float(st.hint["remaining"]) - delta
	if st.hint["remaining"] <= 0.0:
		st.hint["pending"] = false
		st.hint["remaining"] = 0.0
		st.hint["ready"] = true
		return true
	return false


static func cancel(st: GameState) -> void:
	st.hint["pending"] = false
	st.hint["ready"] = false
	st.hint["remaining"] = 0.0


## "Подумать" on a ready thought: content is chosen now (каркас 3.5 п.4).
static func open_ready(st: GameState, current_puzzle: String = "") -> Array:
	var lines: Array = []
	var pending_target := str(st.hint.get("pending_target", ""))
	if pending_target != "" and st.is_solved(pending_target):
		lines.append("HINT-SELF-01")
	var sel := select(st, current_puzzle)
	commit(st, sel)
	if sel["line"] != "":
		lines.append(sel["line"])
	st.hint["ready"] = false
	st.hint["pending_target"] = ""
	return lines
