class_name GameData
extends RefCounted
## Read-only access to the content bundle res://content/game_data.json
## (built from game/data/*.yaml by game/tools/data_build.py).

const DEFAULT_PATH := "res://content/game_data.json"
const LEVELS := ["easy", "normal", "hard"]

var raw: Dictionary = {}
var nodes_by_id: Dictionary = {}
var node_order: Array = []
var values_profile := "test"
var load_error := ""


func load_file(path: String = DEFAULT_PATH) -> bool:
	if not FileAccess.file_exists(path):
		load_error = "content not found: %s (run game/tools/data_build.py)" % path
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "content is not valid JSON: %s" % path
		return false
	raw = parsed
	nodes_by_id.clear()
	node_order.clear()
	for n in raw.get("progression", {}).get("nodes", []):
		nodes_by_id[n["id"]] = n
		node_order.append(n["id"])
	values_profile = str(raw.get("slice", {}).get("debug", {}).get("values_profile", "test"))
	return true


# ------------------------------------------------------------ collections

func _entry(coll: String, id: String) -> Dictionary:
	var c: Dictionary = raw.get(coll, {})
	return c.get(id, {})


func slice() -> Dictionary: return raw.get("slice", {})
func viewpoint(id: String) -> Dictionary: return _entry("viewpoints", id)
func hotspot(id: String) -> Dictionary: return _entry("hotspots", id)
func item(id: String) -> Dictionary: return _entry("items", id)
func clue(id: String) -> Dictionary: return _entry("clues", id)
func document(id: String) -> Dictionary: return _entry("documents", id)
func snapshot(id: String) -> Dictionary: return _entry("snapshots", id)
func code(id: String) -> Dictionary: return _entry("codes", id)
func question(id: String) -> Dictionary: return _entry("questions", id)
func goal(id: String) -> Dictionary: return _entry("goals", id)
func event(id: String) -> Dictionary: return _entry("events", id)
func speaker(id: String) -> Dictionary: return _entry("speakers", id)
func people_entry(id: String) -> Dictionary: return _entry("people", id)
func sign_def(id: String) -> Dictionary: return _entry("signs", id)
func line(id: String) -> Dictionary: return _entry("lines", id)
func node(id: String) -> Dictionary: return nodes_by_id.get(id, {})
func has_line(id: String) -> bool: return raw.get("lines", {}).has(id)
func ids(coll: String) -> Array: return raw.get(coll, {}).keys()


func difficulty_profile(level: String) -> Dictionary:
	return raw.get("difficulty_profile", {}).get("difficulty", {}).get(level, {})


func debug_profile() -> Dictionary:
	return raw.get("difficulty_profile", {}).get("debug", {})


## Values for an entity (PZ-…, IT-…, SNAP-…) and level: "all" merged with the level block.
## Release profile falls back to test while release values are not chosen yet.
func values(id: String, level: String) -> Dictionary:
	var prof: Dictionary = raw.get("values", {}).get(values_profile, {})
	if typeof(prof) != TYPE_DICTIONARY or not prof.has(id):
		prof = raw.get("values", {}).get("test", {})
	var entry: Dictionary = prof.get(id, {})
	var out := {}
	if entry.has("all"):
		out.merge(entry["all"])
	for k in entry.keys():
		if not (k in LEVELS) and k != "all":
			out[k] = entry[k]
	if entry.has(level) and typeof(entry[level]) == TYPE_DICTIONARY:
		out.merge(entry[level], true)
	return out


## Resolves "PZ-GATE-01.pillars" for a level.
func value_path(path: String, level: String) -> Variant:
	var parts := path.split(".", false, 1)
	if parts.size() < 2:
		return null
	return values(parts[0], level).get(parts[1])


# ------------------------------------------------------------ text

## UI string by key in the language, with {param} substitution.
func ui(key: String, lang: String, params: Dictionary = {}) -> String:
	var s: Dictionary = raw.get("strings", {}).get(key, {})
	var text := ""
	if s.is_empty():
		text = "[%s]" % key
	else:
		var v: Variant = s.get(lang)
		if v == null:
			v = s.get("ru", "[%s]" % key)
			if lang != "ru":
				text = "[%s] " % lang.to_upper()
		text += str(v)
	return fill(text, params)


## Line text in the language. Missing EN → RU with "[EN]" mark; missing RU → [TEXT NEEDED: id].
## Lines with template_<lang> use the template when params are given (values differ per level).
func line_text(id: String, lang: String, params: Dictionary = {}) -> String:
	var ln := line(id)
	if ln.is_empty():
		return "[LINE MISSING: %s]" % id
	var text: Variant = null
	if not params.is_empty():
		text = ln.get("template_" + lang)
	if text == null:
		text = ln.get("text_" + lang)
	var mark := ""
	if text == null and lang != "ru":
		text = ln.get("template_ru") if not params.is_empty() and ln.get("template_ru") != null else ln.get("text_ru")
		mark = "[%s] " % lang.to_upper()
	if text == null:
		return "[TEXT NEEDED: %s]" % id
	return mark + fill(str(text), params)


static func fill(text: String, params: Dictionary) -> String:
	var out := text
	for k in params.keys():
		out = out.replace("{%s}" % k, str(params[k]))
	return out


# ------------------------------------------------------------ assets

## Real art (res://assets/<kind>/<name>.*) wins over placeholders (res://assets/placeholder/<kind>/<name>.png).
func texture_path(kind: String, asset_name: String) -> String:
	for ext in ["png", "webp", "jpg"]:
		var p := "res://assets/%s/%s.%s" % [kind, asset_name, ext]
		if ResourceLoader.exists(p):
			return p
	var ph := "res://assets/placeholder/%s/%s.png" % [kind, asset_name]
	if ResourceLoader.exists(ph):
		return ph
	return ""


func texture(kind: String, asset_name: String) -> Texture2D:
	var p := texture_path(kind, asset_name)
	if p == "":
		return null
	return load(p) as Texture2D
