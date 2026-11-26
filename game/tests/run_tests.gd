extends SceneTree
## Headless test runner:  godot --headless --path game -s res://tests/run_tests.gd
## Runs every method named test_* in tests/test_*.gd. Exit code 0 = all passed.

const TEST_FILES := [
	"res://tests/test_pano_math.gd",
	"res://tests/test_code_lock.gd",
	"res://tests/test_game_state.gd",
	"res://tests/test_hints.gd",
	"res://tests/test_content.gd",
]


func _initialize() -> void:
	var data := GameData.new()
	if not data.load_file():
		printerr("FATAL: ", data.load_error)
		quit(2)
		return
	var total := 0
	var failed := 0
	for path in TEST_FILES:
		var script: GDScript = load(path)
		if script == null:
			printerr("FATAL: cannot load ", path)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.data = data
			t.call(name)
			total += 1
			if t.failures.is_empty():
				print("  ok   %s :: %s" % [path.get_file(), name])
			else:
				failed += 1
				for f in t.failures:
					printerr("  FAIL %s :: %s — %s" % [path.get_file(), name, f])
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
