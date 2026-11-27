extends TestCase
## Zone layout from the 3D blockout: viewpoint graph, transition marks, map, gaze carried between viewpoints.


func test_every_viewpoint_on_map_with_heading() -> void:
	for vp_id in data.ids("viewpoints"):
		var m := data.map_vp(vp_id)
		check(not m.is_empty(), "%s on the zone map" % vp_id)
		if m.is_empty():
			continue
		check(float(m["u"]) > 0.0 and float(m["u"]) < 1.0 and float(m["v"]) > 0.0 and float(m["v"]) < 1.0, "%s inside the map image" % vp_id)
	check(data.texture_path("map", str(data.map_data().get("image", ""))) != "", "map image present")


func test_panoramas_are_rendered() -> void:
	for vp_id in data.ids("viewpoints"):
		var pan: String = data.viewpoint(vp_id).get("panorama", "")
		var p := data.texture_path("pano", pan)
		check(p.begins_with("res://assets/pano/"), "%s uses the rendered panorama, got '%s'" % [vp_id, p])


func test_exits_are_two_way_and_labelled() -> void:
	for vp_id in data.ids("viewpoints"):
		for ex in data.viewpoint(vp_id).get("exits", []):
			var back := false
			for ex2 in data.viewpoint(ex["to"]).get("exits", []):
				back = back or ex2["to"] == vp_id
			check(back, "%s → %s has a way back" % [vp_id, ex["to"]])
			check(ex.get("label_key") != null and data.ui(ex["label_key"], "ru") != "" and not data.ui(ex["label_key"], "ru").begins_with("["),
				"%s → %s labelled" % [vp_id, ex["to"]])
			check(float(ex["pitch"]) < 15.0 and float(ex["pitch"]) > -40.0, "%s → %s mark near the ground (uphill may be above the horizon) and reachable by tilt" % [vp_id, ex["to"]])


func test_path_to_lake_between_fountain_and_pier() -> void:
	var st := new_state("normal")
	var ex: Dictionary = Interactions.exits_of(st, "VP-ALLEY-1")[1]
	eq(ex["to"], "VP-PATH-1", "fountain → path")
	var r := Interactions.use_exit(st, ex)
	eq(r["kind"], "move", "walks")
	check(r["lines"].has("DLG-ALLEY-011"), "first descent line on the way down")
	var tos: Array = Interactions.exits_of(st, "VP-PATH-1").map(func(e: Dictionary) -> String: return e["to"])
	check("VP-PIER-1" in tos and "VP-ALLEY-1" in tos, "path leads to the pier and back: %s" % str(tos))


## Mark direction from the data = direction to the target on the map (no hand-placed angles drift).
func test_marks_point_towards_targets_on_map() -> void:
	var md := data.map_data()
	for vp_id in data.ids("viewpoints"):
		var a := data.map_vp(vp_id)
		if a.is_empty() or data.viewpoint(vp_id).get("location") == "":
			continue
		for ex in data.viewpoint(vp_id).get("exits", []):
			if vp_id == "VP-GATE-2" or ex["to"] == "VP-GATE-2":
				continue          # door of the gatehouse: target is behind a wall, mark is on the door
			var b := data.map_vp(ex["to"])
			var dx := (float(b["u"]) - float(a["u"])) * float(md["size_px"][0])
			var dy := (float(b["v"]) - float(a["v"])) * float(md["size_px"][1])
			var world := rad_to_deg(atan2(dx, -dy))
			var yaw := PanoMath.wrap_yaw(world - float(a["heading"]))
			check(absf(PanoMath.yaw_delta(yaw, float(ex["yaw"]))) < 30.0,
				"%s → %s: mark yaw %.0f, target on the map at %.0f" % [vp_id, ex["to"], float(ex["yaw"]), yaw])


func test_gaze_is_carried_between_viewpoints() -> void:
	near(data.carry_yaw(0.0, "VP-GATE-1", "VP-ALLEY-1"), 0.0, 0.01, "same heading → same yaw")
	var h_alley := float(data.map_vp("VP-ALLEY-1")["heading"])
	var h_path := float(data.map_vp("VP-PATH-1")["heading"])
	near(data.carry_yaw(270.0, "VP-ALLEY-1", "VP-PATH-1"), PanoMath.wrap_yaw(270.0 + h_alley - h_path), 0.01, "west stays west")
	near(data.carry_yaw(data.carry_yaw(123.0, "VP-PIER-1", "VP-GATE-2"), "VP-GATE-2", "VP-PIER-1"), 123.0, 0.01, "round trip")


func test_wallclock_overlay_only_on_hard() -> void:
	var ov: Dictionary = {}
	for o in data.viewpoint("VP-GATE-2").get("overlays", []):
		if o["id"] == "wallclock":
			ov = o
	check(not ov.is_empty(), "wall clock overlay exists")
	check(not new_state("normal").cond_ok(ov.get("only_if")), "hidden on normal")
	check(new_state("hard").cond_ok(ov.get("only_if")), "shown on hard")
	var hs: Dictionary = data.hotspot("HS-GATE-WALLCLOCK")["pos"]
	check(PanoMath.angular_distance(hs["yaw"], hs["pitch"], ov["yaw"], ov["pitch"]) < 1.0, "drawn where the hotspot is")
