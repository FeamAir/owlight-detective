extends TestCase


func test_yaw_convention() -> void:
	# yaw 0 = forward (-Z), 90 = right (+X), pitch up = +Y
	var f := PanoMath.dir_from(0, 0)
	near(f.z, -1.0, 1e-5, "forward z")
	var r := PanoMath.dir_from(90, 0)
	near(r.x, 1.0, 1e-5, "right x")
	var u := PanoMath.dir_from(0, 90)
	near(u.y, 1.0, 1e-5, "up y")


func test_roundtrip_angles() -> void:
	for yaw in [0.0, 30.0, 179.0, 181.0, 255.0, 359.0]:
		for pitch in [-40.0, -10.0, 0.0, 25.0]:
			var yp := PanoMath.yaw_pitch_from(PanoMath.dir_from(yaw, pitch))
			near(absf(PanoMath.yaw_delta(yp.x, yaw)), 0.0, 1e-3, "yaw %f" % yaw)
			near(yp.y, pitch, 1e-3, "pitch %f" % pitch)


func test_screen_roundtrip() -> void:
	var size := Vector2(1600, 720)
	for cam in [Vector2(0, 0), Vector2(255, -25), Vector2(350, 30)]:
		for p in [Vector2(800, 360), Vector2(100, 50), Vector2(1500, 700)]:
			var d := PanoMath.screen_to_dir(p, size, cam.x, cam.y, 75.0)
			var s := PanoMath.dir_to_screen(d, size, cam.x, cam.y, 75.0)
			check(s["visible"], "visible %s" % str(p))
			near((s["pos"] as Vector2).distance_to(p), 0.0, 0.01, "screen roundtrip %s cam %s" % [str(p), str(cam)])


func test_centre_of_screen_is_camera_direction() -> void:
	var size := Vector2(1600, 720)
	var d := PanoMath.screen_to_dir(size * 0.5, size, 30.0, -5.0, 75.0)
	var yp := PanoMath.yaw_pitch_from(d)
	near(yp.x, 30.0, 1e-3, "yaw")
	near(yp.y, -5.0, 1e-3, "pitch")


func test_point_right_of_centre_has_bigger_yaw() -> void:
	var size := Vector2(1600, 720)
	var d := PanoMath.screen_to_dir(Vector2(1200, 360), size, 0.0, 0.0, 75.0)
	check(PanoMath.yaw_pitch_from(d).x > 10.0 and PanoMath.yaw_pitch_from(d).x < 90.0, "right half → positive yaw")


func test_uv_contract() -> void:
	near(PanoMath.uv_from(0, 0).x, 0.5, 1e-6, "centre u")
	near(PanoMath.uv_from(90, 0).x, 0.75, 1e-6, "right u")
	near(PanoMath.uv_from(270, 0).x, 0.25, 1e-6, "left u")
	near(PanoMath.uv_from(0, 45).y, 0.25, 1e-6, "up v")


func test_angular_distance_wraps() -> void:
	near(PanoMath.angular_distance(355, 0, 5, 0), 10.0, 1e-3, "wrap")
	near(PanoMath.yaw_delta(350, 10), 20.0, 1e-3, "delta wrap")
