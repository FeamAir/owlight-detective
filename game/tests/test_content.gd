extends TestCase
## Content bundle sanity checks that need the Godot side (assets, text fallback).


func test_all_lines_have_ru_and_en() -> void:
	for id in data.ids("lines"):
		var ln := data.line(id)
		check(ln.get("text_ru") != null, "%s RU" % id)
		check(ln.get("text_en") != null, "%s EN" % id)
		check(ln.has("audio_ru") and ln.has("audio_en"), "%s audio fields (решение №11)" % id)


func test_line_count_matches_spec() -> void:
	eq(data.ids("lines").size(), 126, "126 lines in slice-01-spec v1.1")


func test_text_fallbacks() -> void:
	eq(data.line_text("NO-SUCH", "ru"), "[LINE MISSING: NO-SUCH]", "missing line")
	eq(data.ui("UI-FB-COUNT", "ru", {"n": 2, "m": 3}), "Неверно. Верно 2 из 3", "params")
	eq(data.ui("no.key", "en"), "[no.key]", "missing key")


func test_panoramas_exist() -> void:
	for id in data.ids("viewpoints"):
		var p := data.texture_path("pano", data.viewpoint(id)["panorama"])
		check(p != "", "panorama for %s (run gen_placeholders.py)" % id)


func test_hotspots_in_range() -> void:
	for id in data.ids("hotspots"):
		var pos: Dictionary = data.hotspot(id)["pos"]
		check(float(pos["yaw"]) >= 0 and float(pos["yaw"]) < 360, "%s yaw" % id)
		check(absf(float(pos["pitch"])) <= 40.0 + 37.5, "%s pitch reachable with ±40° tilt" % id)
		check(float(pos["size_deg"]) > 0, "%s size" % id)


func test_values_profile_falls_back_to_test() -> void:
	eq(data.values("PZ-GATE-01", "normal")["code"], "3756", "normal code")
	eq(data.values("IT-OWL", "hard")["owl_base_signs"], ["key", "moon", "owl", "wave"], "'all' block")
