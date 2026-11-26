class_name PanoramaView
extends Control
## 360° view of an equirectangular panorama (дизайн 2.2): swipe with inertia, tilt ±40° with a soft stop,
## tap → hotspot / transition mark by yaw/pitch, long press 0.4 s. Draws the detail layer (signs),
## ink transition marks, easy-level shimmer and the debug overlay (hotspot outlines + yaw/pitch).

signal tapped(pick: Dictionary)          # {type: "hotspot"/"exit"/"none", id, index, yaw, pitch}
signal long_pressed(pick: Dictionary)
signal swiped

const PITCH_LIMIT := 40.0
const TAP_SLOP := 24.0                   # px movement that still counts as a tap
const LONG_PRESS := 0.4
const MIN_TOUCH_UNITS := 48.0            # 24 dp radius = 48 dp target (дизайн 3.0)

var yaw := 0.0
var pitch := 0.0
var vfov := 75.0
var interactive := true
var dim := 0.0:
	set(v):
		dim = v
		if _mat:
			_mat.set_shader_parameter("dim", v)
var blur := 0.0:
	set(v):
		blur = v
		if _mat:
			_mat.set_shader_parameter("blur", v)

var hotspots: Array = []    # [{id, yaw, pitch, size_deg, label, shimmer}]
var exits: Array = []       # [{index, yaw, pitch, locked, icon}]
var decals: Array = []      # [{kind: "sign", sign, yaw, pitch, size_deg}]
var show_debug := false
var shimmer := false

var _mat: ShaderMaterial
var _rect: ColorRect
var _overlay: Control
var _vel := Vector2.ZERO          # deg/s (yaw, pitch)
var _touch_down := false
var _touch_start := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_time := 0.0
var _moved := false
var _long_fired := false
var _last_drag_v := Vector2.ZERO
var _last_tap_info := ""
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rect = ColorRect.new()
	UiKit.full_rect(_rect)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/core/panorama.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_overlay = Control.new()
	UiKit.full_rect(_overlay)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	dim = dim
	blur = blur


func set_texture(tex: Texture2D) -> void:
	_mat.set_shader_parameter("pano", tex)


func look_at_angles(y: float, p: float) -> void:
	yaw = PanoMath.wrap_yaw(y)
	pitch = clampf(p, -PITCH_LIMIT, PITCH_LIMIT)
	_vel = Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	if _touch_down and not _moved and not _long_fired and _time - _touch_time >= LONG_PRESS:
		_long_fired = true
		long_pressed.emit(pick(_touch_start))
	if not _touch_down and _vel.length() > 0.5:
		yaw = PanoMath.wrap_yaw(yaw + _vel.x * delta)
		pitch += _vel.y * delta
		_vel *= pow(0.04, delta)           # inertia with smooth decay
	elif not _touch_down:
		_vel = Vector2.ZERO
	# soft stop at ±40°
	if not _touch_down and absf(pitch) > PITCH_LIMIT:
		pitch = lerpf(pitch, signf(pitch) * PITCH_LIMIT, minf(1.0, delta * 12.0))
		_vel.y = 0.0
	var sz := size
	if sz.y > 0.0:
		_mat.set_shader_parameter("cam_yaw", deg_to_rad(yaw))
		_mat.set_shader_parameter("cam_pitch", deg_to_rad(pitch))
		_mat.set_shader_parameter("tan_half", tan(deg_to_rad(vfov) * 0.5))
		_mat.set_shader_parameter("aspect", sz.x / sz.y)
	_overlay.queue_redraw()


func _gui_input(ev: InputEvent) -> void:
	if not interactive:
		return
	if ev is InputEventScreenTouch:
		if ev.index != 0:
			return
		if ev.pressed:
			_touch_down = true
			_touch_start = ev.position
			_touch_last = ev.position
			_touch_time = _time
			_moved = false
			_long_fired = false
			_vel = Vector2.ZERO
			_last_drag_v = Vector2.ZERO
		else:
			_touch_down = false
			if not _moved and not _long_fired:
				var p := pick(ev.position)
				_last_tap_info = "tap yaw %.1f° pitch %.1f°" % [p["yaw"], p["pitch"]]
				tapped.emit(p)
			elif _moved:
				_vel = _last_drag_v
		accept_event()
	elif ev is InputEventScreenDrag:
		if ev.index != 0 or not _touch_down:
			return
		if not _moved and ev.position.distance_to(_touch_start) > TAP_SLOP:
			_moved = true
			swiped.emit()
		if _moved:
			var deg_per_px := vfov / maxf(size.y, 1.0)
			var d: Vector2 = ev.position - _touch_last
			yaw = PanoMath.wrap_yaw(yaw - d.x * deg_per_px)
			var over := absf(pitch) > PITCH_LIMIT
			pitch = clampf(pitch + d.y * deg_per_px * (0.3 if over else 1.0), -PITCH_LIMIT - 8.0, PITCH_LIMIT + 8.0)
			var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
			_last_drag_v = _last_drag_v.lerp(Vector2(-d.x, d.y) * deg_per_px / dt, 0.5)
		_touch_last = ev.position
		accept_event()


## What is under a screen point. Smaller targets win over big ones (a mark on the gravel beats the gravel).
func pick(pos: Vector2) -> Dictionary:
	var d := PanoMath.screen_to_dir(pos, size, yaw, pitch, vfov)
	var yp := PanoMath.yaw_pitch_from(d)
	var min_r := MIN_TOUCH_UNITS / PanoMath.px_per_degree(size, vfov)
	var best := {"type": "none", "id": "", "index": -1, "yaw": yp.x, "pitch": yp.y}
	var best_r := INF
	var best_ratio := INF
	for e in exits:
		var r := maxf(5.0, min_r)
		var dist := PanoMath.angular_distance(yp.x, yp.y, e["yaw"], e["pitch"])
		if dist <= r and (r < best_r or (r == best_r and dist / r < best_ratio)):
			best = {"type": "exit", "id": "", "index": e["index"], "yaw": yp.x, "pitch": yp.y}
			best_r = r
			best_ratio = dist / r
	for h in hotspots:
		var r2 := maxf(float(h["size_deg"]) * 0.5, min_r)
		var dist2 := PanoMath.angular_distance(yp.x, yp.y, h["yaw"], h["pitch"])
		if dist2 <= r2 and (r2 < best_r or (r2 == best_r and dist2 / r2 < best_ratio)):
			best = {"type": "hotspot", "id": h["id"], "index": -1, "yaw": yp.x, "pitch": yp.y}
			best_r = r2
			best_ratio = dist2 / r2
	return best


func screen_pos(y: float, p: float) -> Dictionary:
	return PanoMath.dir_to_screen(PanoMath.dir_from(y, p), size, yaw, pitch, vfov)


# ------------------------------------------------------------ overlay

func _draw_overlay() -> void:
	var ppd := PanoMath.px_per_degree(size, vfov)
	for dc in decals:
		var s := screen_pos(dc["yaw"], dc["pitch"])
		if not s["visible"]:
			continue
		var r := float(dc["size_deg"]) * 0.5 * ppd
		SignDraw.draw(_overlay, dc["sign"], s["pos"], r, UiKit.IVORY, Color(0.18, 0.18, 0.18))
	if shimmer:
		var a := 0.18 + 0.14 * sin(_time * 3.0)
		for h in hotspots:
			var s2 := screen_pos(h["yaw"], h["pitch"])
			if s2["visible"]:
				_overlay.draw_circle(s2["pos"], maxf(14.0, float(h["size_deg"]) * 0.12 * ppd), Color(UiKit.LAMP, a))
	for e in exits:
		var s3 := screen_pos(e["yaw"], e["pitch"])
		if not s3["visible"]:
			continue
		_draw_mark(s3["pos"], e)
	if show_debug:
		_draw_debug(ppd)


func _draw_mark(p: Vector2, e: Dictionary) -> void:
	# Clara's ink mark: an ellipse drawn with a pen + a chevron; icon by kind (дизайн 2.3).
	var w := 70.0
	var h := 26.0
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(p + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	var col := Color(UiKit.IVORY, 0.75)
	_overlay.draw_polyline(pts, Color(UiKit.INK, 0.8), 7.0)
	_overlay.draw_polyline(pts, col, 3.5)
	_overlay.draw_polyline(PackedVector2Array([p + Vector2(-14, 4), p + Vector2(0, -8), p + Vector2(14, 4)]), col, 4.0)
	var ip := p + Vector2(0, -36)
	if e.get("locked", false):
		_overlay.draw_circle(ip, 13, Color(UiKit.INK, 0.8))
		_overlay.draw_circle(ip + Vector2(0, -3), 5, col)
		_overlay.draw_rect(Rect2(ip + Vector2(-2, -1), Vector2(4, 10)), col)
	elif e.get("icon") == "door":
		_overlay.draw_arc(ip + Vector2(0, 4), 12, PI, TAU, 12, col, 4.0)
		_overlay.draw_line(ip + Vector2(-12, 4), ip + Vector2(-12, 16), col, 4.0)
		_overlay.draw_line(ip + Vector2(12, 4), ip + Vector2(12, 16), col, 4.0)
	else:
		_overlay.draw_colored_polygon(PackedVector2Array([ip + Vector2(0, -12), ip + Vector2(9, 2), ip + Vector2(0, 14), ip + Vector2(-9, 2)]), col)


func _cone_points(cy: float, cp: float, radius_deg: float) -> PackedVector2Array:
	var c := PanoMath.dir_from(cy, cp)
	var t1 := PanoMath.dir_from(cy + 90.0, 0.0)
	var t2 := c.cross(t1).normalized()
	var pts := PackedVector2Array()
	var rho := deg_to_rad(radius_deg)
	for i in 41:
		var th := TAU * i / 40.0
		var d := c * cos(rho) + (t1 * cos(th) + t2 * sin(th)) * sin(rho)
		var s := PanoMath.dir_to_screen(d, size, yaw, pitch, vfov)
		if not s["visible"]:
			return PackedVector2Array()
		pts.append(s["pos"])
	return pts


func _draw_debug(_ppd: float) -> void:
	var font := ThemeDB.fallback_font
	for h in hotspots:
		var pts := _cone_points(h["yaw"], h["pitch"], float(h["size_deg"]) * 0.5)
		if pts.size() > 1:
			_overlay.draw_polyline(pts, Color(1, 0.3, 0.2, 0.9), 3.0)
		var s := screen_pos(h["yaw"], h["pitch"])
		if s["visible"]:
			_overlay.draw_circle(s["pos"], 5, Color(1, 0.3, 0.2))
			_overlay.draw_string(font, s["pos"] + Vector2(8, -8), "%s  %.0f/%.0f/%.0f" % [h["id"], h["yaw"], h["pitch"], h["size_deg"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.85, 0.8))
	for e in exits:
		var s2 := screen_pos(e["yaw"], e["pitch"])
		if s2["visible"]:
			_overlay.draw_string(font, s2["pos"] + Vector2(40, 10), "→ %s %.0f/%.0f" % [e.get("to", ""), e["yaw"], e["pitch"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 1, 0.8))
	var c := size * 0.5
	_overlay.draw_line(c - Vector2(18, 0), c + Vector2(18, 0), Color.WHITE, 2.0)
	_overlay.draw_line(c - Vector2(0, 18), c + Vector2(0, 18), Color.WHITE, 2.0)
	var txt := "yaw %.1f°  pitch %.1f°  fov %.0f°   %s" % [yaw, pitch, vfov, _last_tap_info]
	_overlay.draw_rect(Rect2(Vector2(size.x * 0.5 - 420, 104), Vector2(840, 40)), Color(0, 0, 0, 0.6))
	_overlay.draw_string(font, Vector2(size.x * 0.5 - 410, 134), txt, HORIZONTAL_ALIGNMENT_LEFT, 820, 26, Color(1, 1, 0.7))
