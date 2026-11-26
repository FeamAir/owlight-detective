class_name TestCase
extends RefCounted
## Minimal assertions for headless tests.

var data: GameData
var failures: Array = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: expected <%s>, got <%s>" % [msg, str(expected), str(actual)])


func near(actual: float, expected: float, eps: float, msg: String) -> void:
	if absf(actual - expected) > eps:
		failures.append("%s: expected %f ± %f, got %f" % [msg, expected, eps, actual])


func new_state(level: String) -> GameState:
	var st := GameState.new(data, level)
	for it in data.event("EV-INTRO").get("give_at_start", []):
		st.give(it)
	st.give("IT-OWL")
	return st
