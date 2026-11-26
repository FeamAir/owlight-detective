class_name PuzzleRules
extends RefCounted
## Shared puzzle rules on data: reaction to a wrong answer by level (progression.yaml feedback_mode /
## feedback_rules) and parameters of the "show the logic" line (logic_line) per puzzle and level.
## Pure logic — covered by tests/test_puzzles.gd and tests/test_code_lock.gd.

const DEFAULT_MODE := {"easy": "line", "normal": "wrong_line", "hard": "wrong"}


## Reaction for a wrong answer: {ui: UI string key or "", ui_params: {}, line: line_id or ""}.
## rule — rule name from the screen logic; n / m — correct parts for "count" mode (UI-FB-COUNT).
static func feedback(rule: String, level: String, node: Dictionary, n: int = 0, m: int = 0) -> Dictionary:
	var modes: Dictionary = DEFAULT_MODE.duplicate()
	modes.merge(node.get("feedback_mode", {}), true)
	var mode: String = str(modes.get(level, "wrong"))
	var line := rule_line(rule, level, node)
	var out := {"ui": "", "ui_params": {}, "line": ""}
	match mode:
		"line":
			if line != "":
				out["line"] = line
			else:
				out["ui"] = "UI-FB-WRONG"
		"wrong_line":
			out["ui"] = "UI-FB-WRONG"
			out["line"] = line
		"count":
			out["ui"] = "UI-FB-COUNT"
			out["ui_params"] = {"n": n, "m": m}
		"line_only":
			out["line"] = line
		"wrong":
			out["ui"] = "UI-FB-WRONG"
		"none":
			pass
	return out


## Line for a rule at a level; falls back to the "other" rule. "" when there is none.
static func rule_line(rule: String, level: String, node: Dictionary) -> String:
	for r in node.get("feedback_rules", []):
		if r.get("when") == rule:
			return str(r.get(level, ""))
	for r in node.get("feedback_rules", []):
		if r.get("when") == "other":
			return str(r.get(level, ""))
	return ""


## Parameters of the puzzle's logic_line template for the level and language.
static func logic_params(pz: String, level: String, lang: String, data: GameData) -> Dictionary:
	var v := data.values(pz, level)
	match pz:
		"PZ-GATE-01":
			return CodeLockLogic.logic_params(v, lang, data)
		"PZ-GATE-02":
			return {"rain_end_words": str(v.get("rain_end_words", {}).get(lang, ""))}
		"PZ-GATE-03":
			return ClockLockLogic.logic_params(v, lang)
	return {}


## Ready text of the logic line (what the "solved" card and the notebook "Solved" tab show).
static func logic_text(pz: String, level: String, lang: String, data: GameData) -> String:
	var ln: String = str(data.node(pz).get("logic_line", ""))
	if ln == "":
		return ""
	return data.line_text(ln, lang, logic_params(pz, level, lang, data))
