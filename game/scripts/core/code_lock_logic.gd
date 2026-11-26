class_name CodeLockLogic
extends RefCounted
## PZ-GATE-01 (T01) on data: drums count = code length; order — pillars left to right;
## digit — water level in the bowl with the same sign. Values: values/<profile>.yaml → PZ-GATE-01.


static func expected_code(v: Dictionary) -> String:
	var levels: Dictionary = v.get("levels", {})
	var s := ""
	for p in v.get("pillars", []):
		if levels.has(p):
			s += str(int(levels[p]))
	return s


static func code_length(v: Dictionary) -> int:
	return str(v.get("code", "")).length()


static func is_correct(answer: String, v: Dictionary) -> bool:
	return answer == str(v.get("code", ""))


## Classifies a wrong answer by the rule names used in progression.yaml feedback_rules.
static func classify(answer: String, v: Dictionary, owl_base: Array, data: GameData) -> String:
	if is_correct(answer, v):
		return "correct"
	var levels: Dictionary = v.get("levels", {})
	var code := str(v.get("code", ""))
	# (1) levels of the signs from the owl's base (in that order), those that have bowls
	var owl := ""
	for s in owl_base:
		if levels.has(s):
			owl += str(int(levels[s]))
	if owl.length() >= answer.length() and owl.substr(0, answer.length()) == answer:
		return "owl_base_order"
	# (2) sign numbers in pillar order
	var nums := ""
	for p in v.get("pillars", []):
		nums += str(int(data.sign_def(p).get("number", 0)))
	if nums == answer:
		return "sign_numbers"
	# (3) a digit that no bowl has
	var bowl_digits: Array = []
	for lv in levels.values():
		bowl_digits.append(str(int(lv)))
	for ch in answer:
		if not bowl_digits.has(ch):
			return "digit_not_in_bowls"
	# (4) the right digits in the wrong order
	var a := Array(answer.split(""))
	var c := Array(code.split(""))
	a.sort()
	c.sort()
	if a == c:
		return "right_digits_wrong_order"
	return "other"


## Reaction for a wrong answer: {ui: "UI-FB-WRONG" or "", line: line_id or ""}.
## Easy — a line that says what is wrong; normal — "Wrong" + line; hard — only "Wrong" (каркас, 4.4).
static func feedback(rule: String, level: String, node: Dictionary) -> Dictionary:
	var fb := PuzzleRules.feedback(rule, level, node)
	return {"ui": fb["ui"], "line": fb["line"]}


## Parameters for the LOGIC-GATE-01 template in a language: {pillars}, {levels}.
static func logic_params(v: Dictionary, lang: String, data: GameData) -> Dictionary:
	var names: Array = []
	var words: Array = []
	var levels: Dictionary = v.get("levels", {})
	for p in v.get("pillars", []):
		names.append(data.ui("sign." + p, lang))
		if levels.has(p):
			words.append(data.ui("num.loc.%d" % int(levels[p]), lang))
	return {"pillars": ", ".join(names), "levels": join_and(words, data.ui("list.and", lang))}


static func join_and(words: Array, and_word: String) -> String:
	if words.size() <= 1:
		return "".join(words)
	return ", ".join(words.slice(0, words.size() - 1)) + and_word + str(words[-1])
