class_name Interactions
extends RefCounted
## What happens on a tap at a hotspot or a transition mark, entering a viewpoint, the slice end.
## Mutates GameState and returns a description for the UI:
##   {kind, lines: [line_id], given: [ids], puzzle, asset, doc, to, tutorial, unseen_zones, boundary_label}
## kind: closeup | puzzle | line | document | locked | move | slice_end | slice_end_confirm | none


static func _result() -> Dictionary:
	return {"kind": "none", "lines": [], "given": [], "puzzle": "", "asset": "", "doc": "",
			"to": "", "tutorial": "", "unseen_zones": [], "boundary_label": false, "hotspot": ""}


static func _add_line(res: Dictionary, line_id: Variant) -> void:
	if line_id != null and str(line_id) != "" and not res["lines"].has(line_id):
		res["lines"].append(line_id)


static func _give(st: GameState, res: Dictionary, id: String) -> void:
	if st.give(id) != "":
		res["given"].append(id)


## Effects block (on_first / state): line, lines, set, give, question, autosnap, autocode, tutorial_if.
static func apply_effects(st: GameState, eff: Dictionary, res: Dictionary) -> void:
	_add_line(res, eff.get("line"))
	for ln in eff.get("lines", []):
		_add_line(res, ln)
	var once: Variant = eff.get("line_once")
	if once != null and not st.has("line." + str(once)):
		_add_line(res, once)
	for f in eff.get("set", []):
		st.set_flag(f)
	for g in eff.get("give", []):
		_give(st, res, g)
	var q: Variant = eff.get("question")
	if q != null:
		var qid: String = q["id"] if typeof(q) == TYPE_DICTIONARY else str(q)
		var allowed: bool = true
		if typeof(q) == TYPE_DICTIONARY and q.has("levels"):
			allowed = st.difficulty in q["levels"]
		if allowed and st.give_question(qid):
			res["given"].append(qid)
	var snap: Variant = GameState.level_rule(eff.get("autosnap"), st.difficulty)
	if typeof(snap) == TYPE_STRING:
		_give(st, res, snap)
	var code: Variant = GameState.level_rule(eff.get("autocode"), st.difficulty)
	if typeof(code) == TYPE_STRING:
		_give(st, res, code)
	var tut: Variant = eff.get("tutorial_if")
	if tut != null and st.cond_ok(tut):
		res["tutorial"] = tut.get("ui", "")


## Hotspot visible at this level (only_if, e.g. wall clock only on hard).
static func hotspot_active(st: GameState, hs: Dictionary) -> bool:
	return st.cond_ok(hs.get("only_if"))


static func tap_hotspot(st: GameState, hs_id: String) -> Dictionary:
	var res := _result()
	res["hotspot"] = hs_id
	var hs := st.data.hotspot(hs_id)
	if hs.is_empty() or not hotspot_active(st, hs):
		return res
	var act: Dictionary = hs.get("action", {})
	var first := not st.has("seen.hs." + hs_id)
	st.set_flag("seen.hs." + hs_id)
	if first and hs.has("on_first"):
		apply_effects(st, hs["on_first"], res)
	# pick the state whose condition holds
	var a: Dictionary = act
	for state in act.get("states", []):
		if st.cond_ok(state.get("when")):
			a = state
			break
	var kind: String = str(a.get("kind", act.get("kind", "line")))
	match kind:
		"closeup":
			res["kind"] = "closeup"
			res["asset"] = str(act.get("asset", "cu_generic"))
			var snap: Variant = GameState.level_rule(act.get("autosnap"), st.difficulty)
			if typeof(snap) == TYPE_STRING:
				_give(st, res, snap)
			if a != act:
				apply_effects(st, a, res)
			if a.has("open_puzzle"):
				res["puzzle"] = a["open_puzzle"]
		"puzzle":
			var pz: String = str(a.get("puzzle", act.get("puzzle", "")))
			var after: Dictionary = hs.get("after_solved", {})
			if st.is_solved(pz) and after.get("kind") == "exit":
				res["kind"] = "move"
				res["to"] = after["to"]
			else:
				res["kind"] = "puzzle"
				res["puzzle"] = pz
				st.last_puzzle = pz
		"line":
			res["kind"] = "line"
			_add_line(res, a.get("line"))
		"document":
			res["kind"] = "document"
			res["doc"] = str(act.get("doc", ""))
			_give(st, res, res["doc"])
		"locked":
			res["kind"] = "locked"
			_add_line(res, act.get("line"))
			var q: Variant = act.get("question")
			if q != null and st.give_question(q):
				res["given"].append(q)
		"slice_boundary":
			_boundary(st, hs_id, res)
	return res


static func _boundary(st: GameState, hs_id: String, res: Dictionary) -> void:
	var sl := st.data.slice()
	var end: Dictionary = sl.get("end", {})
	var b: Dictionary = {}
	for e in sl.get("boundary_exits", []):
		if e["hotspot"] == hs_id:
			b = e
	res["boundary_label"] = bool(sl.get("debug", {}).get("label_boundary", false))
	var is_end_door: bool = end.get("trigger", {}).get("tap", "") == hs_id
	var has_key := true
	for it in end.get("requires", {}).get("items", []):
		if not st.inventory.has(it):
			has_key = false
	if is_end_door and has_key:
		var unsolved: Array = []
		var conf: Dictionary = end.get("confirm_if_unsolved", {})
		for pz in conf.get("puzzles", []):
			if not st.is_solved(pz):
				unsolved.append(pz)
		if unsolved.is_empty():
			res["kind"] = "slice_end"
			_add_line(res, end.get("line_on_enter"))
		else:
			res["kind"] = "slice_end_confirm"
			_add_line(res, conf.get("line"))
			if conf.get("list_unsolved", {}).get(st.difficulty, false):
				for pz in unsolved:
					var loc: String = str(st.data.node(pz).get("location", ""))
					if loc != "" and not res["unseen_zones"].has(loc):
						res["unseen_zones"].append(loc)
	else:
		res["kind"] = "locked"
		_add_line(res, b.get("line"))


## Tap on a transition mark.
static func use_exit(st: GameState, ex: Dictionary) -> Dictionary:
	var res := _result()
	var gate: Variant = ex.get("gate")
	if gate != null and not st.gate_open(gate):
		var pz: Variant = ex.get("on_locked", {}).get("open_puzzle")
		if pz != null:
			res["kind"] = "puzzle"
			res["puzzle"] = pz
			st.last_puzzle = pz
		else:
			res["kind"] = "locked"
		return res
	res["kind"] = "move"
	res["to"] = ex["to"]
	var once: Variant = ex.get("first_use_line")
	if once != null and not st.has("line." + str(once)):
		_add_line(res, once)
	return res


## Arriving at a viewpoint: visited flag, first-entry line, "on_enter_once_when" line.
static func enter_viewpoint(st: GameState, vp_id: String) -> Array:
	var lines: Array = []
	var vp := st.data.viewpoint(vp_id)
	st.vp = vp_id
	var first := not st.has("vp." + vp_id)
	st.set_flag("vp." + vp_id)
	if first and vp.get("first_entry_line") != null:
		lines.append(vp["first_entry_line"])
	var eo: Variant = vp.get("on_enter_once_when")
	if eo != null and not first and st.cond_ok(eo) and not st.has("once." + vp_id):
		st.set_flag("once." + vp_id)
		lines.append(eo["line"])
	elif eo != null and first and st.cond_ok(eo):
		st.set_flag("once." + vp_id)
	return lines


## Exit list with "locked" state for drawing marks.
static func exits_of(st: GameState, vp_id: String) -> Array:
	var out: Array = []
	for ex in st.data.viewpoint(vp_id).get("exits", []):
		var e: Dictionary = ex.duplicate()
		e["locked"] = ex.get("gate") != null and not st.gate_open(ex["gate"])
		out.append(e)
	return out
