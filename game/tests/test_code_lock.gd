extends TestCase
## PZ-GATE-01: answers and reactions on every level (test-set-01, spec 5.1, values/test.yaml).


func _v(level: String) -> Dictionary:
	return data.values("PZ-GATE-01", level)


func _owl() -> Array:
	return data.values("IT-OWL", "normal").get("owl_base_signs", [])


func test_codes_follow_pillars_and_water() -> void:
	eq(CodeLockLogic.expected_code(_v("easy")), "375", "easy")
	eq(CodeLockLogic.expected_code(_v("normal")), "3756", "normal")
	eq(CodeLockLogic.expected_code(_v("hard")), "2946", "hard")
	for lvl in GameData.LEVELS:
		eq(CodeLockLogic.expected_code(_v(lvl)), str(_v(lvl)["code"]), "data code = derived code " + lvl)
		eq(CodeLockLogic.code_length(_v(lvl)), str(_v(lvl)["code"]).length(), "drums " + lvl)


func test_correct() -> void:
	check(CodeLockLogic.is_correct("3756", _v("normal")), "3756 opens normal")
	check(not CodeLockLogic.is_correct("3756", _v("hard")), "3756 does not open hard")
	eq(CodeLockLogic.classify("375", _v("easy"), _owl(), data), "correct", "easy correct")


func test_wrong_answers_classified() -> void:
	var n := _v("normal")
	eq(CodeLockLogic.classify("5736", n, _owl(), data), "right_digits_wrong_order", "fountain order (test-set row 1)")
	eq(CodeLockLogic.classify("7356", n, _owl(), data), "right_digits_wrong_order", "permutation")
	eq(CodeLockLogic.classify("4132", n, _owl(), data), "sign_numbers", "sign numbers (test-set row 2)")
	eq(CodeLockLogic.classify("3751", n, _owl(), data), "digit_not_in_bowls", "digit 1 not in bowls")
	eq(CodeLockLogic.classify("3757", n, _owl(), data), "other", "digits from bowls, not the code")
	eq(CodeLockLogic.classify("637", _v("easy"), _owl(), data), "owl_base_order", "owl base Key-Moon-Owl (spec 5.1 p.3)")
	eq(CodeLockLogic.classify("413", _v("easy"), _owl(), data), "sign_numbers", "easy sign numbers")


func test_feedback_by_level() -> void:
	var node := data.node("PZ-GATE-01")
	eq(CodeLockLogic.feedback("right_digits_wrong_order", "easy", node), {"ui": "", "line": "FB-GATE01-E1"}, "easy order")
	eq(CodeLockLogic.feedback("sign_numbers", "easy", node)["line"], "FB-GATE01-E2", "easy E2")
	eq(CodeLockLogic.feedback("digit_not_in_bowls", "easy", node)["line"], "FB-GATE01-E3", "easy E3")
	eq(CodeLockLogic.feedback("owl_base_order", "easy", node)["line"], "FB-GATE01-E4", "easy E4")
	eq(CodeLockLogic.feedback("right_digits_wrong_order", "normal", node), {"ui": "UI-FB-WRONG", "line": "FB-GATE01-N1"}, "normal N1")
	eq(CodeLockLogic.feedback("sign_numbers", "normal", node)["line"], "FB-GATE01-N2", "normal N2")
	eq(CodeLockLogic.feedback("digit_not_in_bowls", "normal", node)["line"], "FB-GATE01-N3", "normal N3")
	eq(CodeLockLogic.feedback("sign_numbers", "hard", node), {"ui": "UI-FB-WRONG", "line": ""}, "hard: only Wrong")


func test_logic_line_template_matches_canon() -> void:
	var p := CodeLockLogic.logic_params(_v("normal"), "ru", data)
	eq(data.line_text("LOGIC-GATE-01", "ru", p), data.line_text("LOGIC-GATE-01", "ru"), "RU template on normal = canon text")
	var pe := CodeLockLogic.logic_params(_v("normal"), "en", data)
	eq(data.line_text("LOGIC-GATE-01", "en", pe), data.line_text("LOGIC-GATE-01", "en"), "EN template on normal = canon text")
	var ph := CodeLockLogic.logic_params(_v("hard"), "ru", data)
	eq(data.line_text("LOGIC-GATE-01", "ru", ph), "Шестерня, Ключ, Сова, Луна — по столбам слева направо. В их чашах вода на двух, девяти, четырёх и шести.", "hard RU")
