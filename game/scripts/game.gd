extends Node
## Autoload "Game": content, current game state, settings, autosave, hint timer.

signal state_changed            # bag / notebook / goals / hint state changed — HUD refreshes
signal hint_ready
signal language_changed

const SAVE_PATH := "user://save_slot1.json"
const SETTINGS_PATH := "user://settings.json"

var data := GameData.new()
var state: GameState = null
var settings := {
	"lang": "ru",
	"text_speed": "fast",          # instant / fast / normal (дизайн 3.9)
	"debug_overlay": false,        # contours of hotspots + yaw/pitch
	"debug_fast_hints": false,     # 5 min → N s
}
var debug_build := OS.is_debug_build()
var current_puzzle := ""         # puzzle screen open now ("" if none) — for "ready" hints
var last_save_error := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not data.load_file():
		push_error(data.load_error)
	_load_settings()
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)


func _process(delta: float) -> void:
	if state == null or not state.intro_done or state.slice_ended:
		return
	state.play_time += delta
	if current_puzzle != "":
		var s := state.stats_for(current_puzzle)
		s["time"] = float(s["time"]) + delta
	var speed := 1.0
	if settings["debug_fast_hints"]:
		speed = 300.0 / float(data.debug_profile().get("hint_wait_seconds_fast", 10))
	if Hints.tick(state, delta * speed):
		hint_ready.emit()
		state_changed.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		autosave()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()


## Owner build with "hotspot outlines" on (main menu → Debug): service captions, outlines, yaw/pitch.
func debug_overlay_on() -> bool:
	return debug_build and bool(settings["debug_overlay"])


# ------------------------------------------------------------ text helpers

func lang() -> String:
	return settings["lang"]


func t(key: String, params: Dictionary = {}) -> String:
	return data.ui(key, lang(), params)


func line(id: String, params: Dictionary = {}) -> String:
	return data.line_text(id, lang(), params)


func speaker_name(line_id: String) -> String:
	var ln := data.line(line_id)
	var sp := str(ln.get("speaker_id", ""))
	if sp == "CLARA" and ln.get("style") == "thought":
		return t("speaker.CLARA.thought")
	return t("speaker." + sp)


func set_language(l: String) -> void:
	settings["lang"] = l
	save_settings()
	language_changed.emit()


# ------------------------------------------------------------ game lifecycle

func new_game(level: String) -> void:
	state = GameState.new(data, level)
	current_puzzle = ""


## Debug "start from a point": skip the prologue, mark puzzles solved (owner build only).
func new_game_at(level: String, sp: Dictionary) -> void:
	new_game(level)
	var intro := data.event("EV-INTRO")
	for it in intro.get("give_at_start", []):
		state.give(it)
	for fr in intro.get("frames", []):
		for it in fr.get("give", []):
			state.give(it)
		if fr.get("autosnap") != null:
			state.give(fr["autosnap"])
		for ln in fr.get("lines", []):
			state.note_line(ln)
	state.give("DOC-LETTER")
	for ln in data.event("EV-GATE-DIALOG").get("lines", []):
		state.note_line(ln)
	_apply_gate_dialog_end()
	for pz in sp.get("solved", []):
		state.solve(pz)
	state.intro_done = true
	state.tutorial["done"] = true
	state.vp = sp.get("vp", "VP-GATE-1")
	state.news = {"bag": 0, "notebook": 0}


func _apply_gate_dialog_end() -> void:
	var on_end: Dictionary = data.event("EV-GATE-DIALOG").get("on_end", {})
	if on_end.has("question"):
		state.give_question(on_end["question"])


func finish_intro() -> void:
	_apply_gate_dialog_end()
	state.intro_done = true
	state.vp = data.slice().get("start", {}).get("then", {}).get("vp", "VP-GATE-1")
	state.yaw = float(data.slice().get("start", {}).get("then", {}).get("yaw", 0))
	autosave()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_summary() -> Dictionary:
	var d := _read_json(SAVE_PATH)
	return d


func autosave() -> void:
	if state == null or not state.intro_done:
		return
	var f := FileAccess.open(SAVE_PATH + ".tmp", FileAccess.WRITE)
	if f == null:
		last_save_error = "cannot write save: %d" % FileAccess.get_open_error()
		push_warning(last_save_error)
		return
	f.store_string(JSON.stringify(state.to_dict()))
	f.close()
	DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)


func load_game() -> bool:
	var d := _read_json(SAVE_PATH)
	if d.is_empty():
		return false
	var st := GameState.new(data)
	var err := st.from_dict(d)
	if err != "":
		last_save_error = err
		push_warning("save rejected: " + err)
		return false
	state = st
	current_puzzle = ""
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _load_settings() -> void:
	var d := _read_json(SETTINGS_PATH)
	for k in d.keys():
		if settings.has(k):
			settings[k] = d[k]


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))


## Owner build: protocol of the run (time, attempts, hints per puzzle) — spec 2.5, test-set 0.5.
func protocol_text() -> String:
	if state == null:
		return ""
	var lines: Array = []
	lines.append("Owlight slice 01 — протокол / protocol")
	lines.append("difficulty: %s; time: %s; errors: %d; hints: %d" % [state.difficulty, format_time(state.play_time), state.errors, state.hints_used])
	for pz in state.puzzles():
		var s := state.stats_for(pz)
		lines.append("%s: %s, attempts %d, errors %d, hints %d, time %s" % [
			pz, "solved" if state.is_solved(pz) else "—", int(s["attempts"]), int(s["errors"]), int(s["hints"]), format_time(float(s["time"]))])
	return "\n".join(lines)


func export_protocol() -> String:
	var path := "user://protocol_%d.txt" % int(Time.get_unix_time_from_system())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(protocol_text())
		return ProjectSettings.globalize_path(path)
	return ""


static func format_time(sec: float) -> String:
	var s := int(sec)
	return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
