class_name GameState
extends RefCounted
## Everything that goes into a save: difficulty, flags, bag, notebook, position, hint timer, stats.
## Pure logic (no nodes) — covered by tests/test_game_state.gd.
##
## Flags (slice-01-spec 8): seen.<id>, solved.<PZ>, has.<IT> (from the bag), ev.<EV>, vp.<VP> (visited),
## line.<DLG> (was shown), difficulty.<level>, gate.<GT> (open).

const SAVE_VERSION := 1
const LINE_LOG_MAX := 50

var data: GameData
var difficulty := "normal"
var flags: Dictionary = {}
var inventory: Array = []
var clues: Array = []
var documents: Array = []
var snapshots: Array = []
var codes: Array = []
var questions: Array = []
var thoughts_log: Array = []      # [{line, vp}]
var solved_order: Array = []
var line_log: Array = []          # [line_id]
var vp := ""
var yaw := 0.0
var pitch := 0.0
var intro_done := false
var slice_ended := false
var play_time := 0.0
var errors := 0
var hints_used := 0
var puzzle_stats: Dictionary = {} # pz -> {attempts, errors, hints, time}
var puzzle_progress: Dictionary = {}
var last_puzzle := ""
var hint: Dictionary = {}
var tutorial: Dictionary = {}
var news: Dictionary = {"bag": 0, "notebook": 0}


func _init(game_data: GameData = null, level: String = "normal") -> void:
	data = game_data
	difficulty = level
	reset_hint()
	tutorial = {"step": 0, "done": false, "extra_shown": false}


func reset_hint() -> void:
	hint = {"pending": false, "remaining": 0.0, "ready": false, "pending_target": "",
			"last_target": "", "last_stage": "", "counts": {}, "requests": 0}


# ------------------------------------------------------------ flags & conditions

func has(flag: String) -> bool:
	if flag.begins_with("has."):
		return inventory.has(flag.substr(4))
	if flag.begins_with("difficulty."):
		return difficulty == flag.substr(11)
	return flags.has(flag)


func set_flag(flag: String) -> void:
	flags[flag] = true


## Condition: null / "" → true; "flag" ; {flag: …} / {not_flag: …}; Array → all of them.
func cond_ok(cond: Variant) -> bool:
	if cond == null:
		return true
	match typeof(cond):
		TYPE_STRING:
			return cond == "" or has(cond)
		TYPE_DICTIONARY:
			if cond.has("flag") and not has(cond["flag"]):
				return false
			if cond.has("not_flag") and has(cond["not_flag"]):
				return false
			return true
		TYPE_ARRAY:
			for c in cond:
				if not cond_ok(c):
					return false
			return true
	return true


func is_solved(pz: String) -> bool:
	return has("solved." + pz)


func gate_open(gt: String) -> bool:
	return has("gate." + gt)


# ------------------------------------------------------------ giving things

## Adds an entity by its ID prefix. Returns the collection name, or "" if it was already there.
func give(id: String) -> String:
	var coll := ""
	var arr: Array
	if id.begins_with("IT-"):
		coll = "bag"; arr = inventory
	elif id.begins_with("CL-"):
		coll = "clues"; arr = clues
	elif id.begins_with("DOC-"):
		coll = "documents"; arr = documents
	elif id.begins_with("SNAP-"):
		coll = "snapshots"; arr = snapshots
	elif id.begins_with("CODE-"):
		coll = "codes"; arr = codes
	elif id.begins_with("Q-"):
		coll = "questions"; arr = questions
	elif id.begins_with("GT-"):
		if gate_open(id):
			return ""
		set_flag("gate." + id)
		return "gates"
	else:
		return ""
	if arr.has(id):
		return ""
	arr.append(id)
	if coll == "bag":
		news["bag"] = int(news.get("bag", 0)) + 1
	else:
		news["notebook"] = int(news.get("notebook", 0)) + 1
	return coll


func remove_item(id: String) -> void:
	inventory.erase(id)


## Snapshot auto-rule {easy: true} / {all: SNAP-…}: returns true when the level gets it automatically.
static func level_rule(rule: Variant, level: String) -> Variant:
	if typeof(rule) != TYPE_DICTIONARY:
		return rule
	if rule.has("all"):
		return rule["all"]
	return rule.get(level)


func question_visible(qid: String) -> bool:
	var q := data.question(qid)
	if q.is_empty():
		return false
	if not (difficulty in q.get("levels", [])):
		return false
	return true


## Adds a question if the level shows it (7.2: hard — only locked objects).
func give_question(qid: String) -> bool:
	if not question_visible(qid):
		return false
	return give(qid) != ""


func note_line(line_id: String) -> void:
	set_flag("line." + line_id)
	line_log.append(line_id)
	if line_log.size() > LINE_LOG_MAX:
		line_log = line_log.slice(line_log.size() - LINE_LOG_MAX)


# ------------------------------------------------------------ puzzles & progression

func requirements_met(node: Dictionary) -> bool:
	var req: Dictionary = node.get("requires", {})
	for dep in req.get("all_of", []):
		if str(dep).begins_with("GT-"):
			if not gate_open(dep):
				return false
		elif not is_solved(dep):
			return false
	for it in req.get("items", []):
		if not inventory.has(it):
			return false
	return true


## Knowledge needed to solve (seen.* flags). The hint system says "ready" or "missing" from this.
func knows_met(node: Dictionary) -> bool:
	for f in node.get("requires", {}).get("knows", []):
		if not has(f):
			return false
	for d in node.get("requires", {}).get("docs", []):
		if not (documents.has(d) or snapshots.has(d)):
			return false
	return true


func stats_for(pz: String) -> Dictionary:
	if not puzzle_stats.has(pz):
		puzzle_stats[pz] = {"attempts": 0, "errors": 0, "hints": 0, "time": 0.0}
	return puzzle_stats[pz]


func record_attempt(pz: String, correct: bool) -> void:
	var s := stats_for(pz)
	s["attempts"] = int(s["attempts"]) + 1
	if not correct:
		s["errors"] = int(s["errors"]) + 1
		errors += 1


## Marks a puzzle solved and applies its unlocks. Returns the list of given IDs (for toasts).
func solve(pz: String) -> Array:
	if is_solved(pz):
		return []
	var node := data.node(pz)
	set_flag("solved." + pz)
	solved_order.append(pz)
	var given: Array = []
	for u in node.get("unlocks", []):
		if give(u) != "":
			given.append(u)
	for iid in data.ids("items"):
		var it := data.item(iid)
		if pz in it.get("consumed_by", []) and inventory.has(iid):
			remove_item(iid)
			var to_doc: Variant = it.get("after_consumed", {}).get("to_doc")
			if to_doc != null and give(to_doc) != "":
				given.append(to_doc)
	var snap: Variant = node.get("on_solved_snap")
	if snap != null and give(snap) != "":
		given.append(snap)
	if last_puzzle == pz:
		last_puzzle = ""
	return given


func puzzles() -> Array:
	var out: Array = []
	for id in data.node_order:
		if data.node(id).get("kind") == "puzzle":
			out.append(id)
	return out


func solved_count() -> int:
	var n := 0
	for p in puzzles():
		if is_solved(p):
			n += 1
	return n


func clues_found(counted: Array) -> int:
	var n := 0
	for c in counted:
		if clues.has(c):
			n += 1
	return n


# ------------------------------------------------------------ notebook views

## Open goals, main goals first: [{id, main}]
func active_goals() -> Array:
	var main: Array = []
	var side: Array = []
	for gid in data.ids("goals"):
		var g := data.goal(gid)
		if has(g["opens_on"]) and not has(g["closes_on"]):
			if g.get("main", false):
				main.append(gid)
			else:
				side.append(gid)
	return main + side


func open_questions() -> Array:
	var out: Array = []
	for qid in questions:
		var q := data.question(qid)
		var closes: Variant = q.get("closes_on")
		if closes != null and has(closes):
			continue
		out.append(qid)
	return out


# ------------------------------------------------------------ save

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"difficulty": difficulty,
		"flags": flags.keys(),
		"inventory": inventory, "clues": clues, "documents": documents, "snapshots": snapshots,
		"codes": codes, "questions": questions, "thoughts_log": thoughts_log,
		"solved_order": solved_order, "line_log": line_log,
		"vp": vp, "yaw": yaw, "pitch": pitch,
		"intro_done": intro_done, "slice_ended": slice_ended,
		"play_time": play_time, "errors": errors, "hints_used": hints_used,
		"puzzle_stats": puzzle_stats, "puzzle_progress": puzzle_progress,
		"last_puzzle": last_puzzle, "hint": hint, "tutorial": tutorial, "news": news,
		"saved_at": Time.get_unix_time_from_system(),
	}


## Returns "" on success or an error text. Older versions are migrated here when the format changes.
func from_dict(d: Dictionary) -> String:
	var ver := int(d.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		return "unsupported save version %d" % ver
	difficulty = str(d.get("difficulty", "normal"))
	if not (difficulty in GameData.LEVELS):
		return "bad difficulty %s" % difficulty
	flags.clear()
	for f in d.get("flags", []):
		flags[str(f)] = true
	inventory = Array(d.get("inventory", []))
	clues = Array(d.get("clues", []))
	documents = Array(d.get("documents", []))
	snapshots = Array(d.get("snapshots", []))
	codes = Array(d.get("codes", []))
	questions = Array(d.get("questions", []))
	thoughts_log = Array(d.get("thoughts_log", []))
	solved_order = Array(d.get("solved_order", []))
	line_log = Array(d.get("line_log", []))
	vp = str(d.get("vp", ""))
	yaw = float(d.get("yaw", 0.0))
	pitch = float(d.get("pitch", 0.0))
	intro_done = bool(d.get("intro_done", false))
	slice_ended = bool(d.get("slice_ended", false))
	play_time = float(d.get("play_time", 0.0))
	errors = int(d.get("errors", 0))
	hints_used = int(d.get("hints_used", 0))
	puzzle_stats = d.get("puzzle_stats", {})
	puzzle_progress = d.get("puzzle_progress", {})
	last_puzzle = str(d.get("last_puzzle", ""))
	reset_hint()
	hint.merge(d.get("hint", {}), true)
	tutorial.merge(d.get("tutorial", {}), true)
	news.merge(d.get("news", {}), true)
	return ""
