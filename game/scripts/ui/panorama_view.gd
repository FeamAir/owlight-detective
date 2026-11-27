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
var exits: Array = []       # [{index, yaw, pitch, locked, icon, to, label, fresh}]
var decals: Array = []      # [{kind: "sign"/"wallclock", sign, yaw, pitch, size_deg}]
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
var _mark_seen_at := {}           # exit "to" → time the mark first came on screen in this visit (pulse)

const MARK_PULSE_TIME := 3.0      # strong pulse after a mark first appears on screen
const MARK_LABEL_FONT := 30


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


## New viewpoint: marks pulse again when they first come on screen.
func reset_marks() -> void:
	_mark_seen_at.clear()


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
		var r := maxf(5.0, min_r * 1.3)
		var dist := PanoMath.angular_distance(yp.x, yp.y, e["yaw"], e["pitch"])
		var sm := screen_pos(e["yaw"], e["pitch"])
		if sm["visible"] and Rect2(sm["pos"] + Vector2(-110, -70), Vector2(220, 140)).has_point(pos):
			dist = minf(dist, r * 0.5)        # the whole mark (icon, ellipse, label) is a tap target
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
		if dc.get("kind", "sign") == "wallclock":
			_draw_wallclock(s["pos"], r)
		else:
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


func _draw_wallclock(p: Vector2, r: float) -> void:
	# ходики (hard only): round face, two hands, swinging pendulum
	_overlay.draw_rect(Rect2(p + Vector2(-r * 0.8, -r * 0.9), Vector2(r * 1.6, r * 3.2)), Color(UiKit.WALNUT, 0.95))
	_overlay.draw_circle(p, r * 0.7, UiKit.IVORY)
	_overlay.draw_arc(p, r * 0.7, 0, TAU, 24, UiKit.INK, 2.0)
	_overlay.draw_line(p, p + Vector2(0, -r * 0.5), UiKit.INK, 2.0)
	_overlay.draw_line(p, p + Vector2(r * 0.35, r * 0.1), UiKit.INK, 2.0)
	var a := sin(_time * 3.2) * 0.35
	var bob := p + Vector2(0, r * 0.8) + Vector2(sin(a), cos(a)) * r * 1.2
	_overlay.draw_line(p + Vector2(0, r * 0.8), bob, UiKit.BRASS, 2.0)
	_overlay.draw_circle(bob, r * 0.18, UiKit.BRASS)


## Clara's ink mark, enlarged for the phone (owner, 27.11): ellipse on the ground + chevron, an icon plate above
## (дизайн 2.3: arch = door, leaf/path = outdoors, keyhole = locked) and a label plate below saying where it leads.
## Pulses for a few seconds when it first comes on screen; keeps a soft glow while the place is not visited yet.
func _draw_mark(p: Vector2, e: Dictionary) -> void:
	var key := str(e.get("to", e["index"]))
	if not _mark_seen_at.has(key):
		_mark_seen_at[key] = _time
	var age := _time - float(_mark_seen_at[key])
	var pulse := 0.0
	if age < MARK_PULSE_TIME:
		pulse = (0.5 + 0.5 * sin(age * TAU * 1.4)) * (1.0 - age / MARK_PULSE_TIME)
	elif e.get("fresh", false):
		pulse = 0.25 * (0.5 + 0.5 * sin(_time * 3.0))
	var k := 1.0 + 0.22 * pulse
	var w := 120.0 * k
	var h := 44.0 * k
	var ink := Color(UiKit.INK, 0.85)
	var col := Color(UiKit.IVORY, 0.95)
	if pulse > 0.01:
		_overlay.draw_circle(p, w * 0.62, Color(UiKit.LAMP, 0.28 * pulse))
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(p + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5))
	_overlay.draw_colored_polygon(pts, Color(UiKit.INK, 0.35))
	_overlay.draw_polyline(pts, ink, 9.0)
	_overlay.draw_polyline(pts, col, 4.5)
	var ch := PackedVector2Array([p + Vector2(-20, 7) * k, p + Vector2(0, -10) * k, p + Vector2(20, 7) * k])
	_overlay.draw_polyline(ch, ink, 9.0)
	_overlay.draw_polyline(ch, col, 5.0)
	# icon plate above
	var ip := p + Vector2(0, -h * 0.5 - 30.0 * k)
	_overlay.draw_circle(ip, 25.0 * k, Color(UiKit.LAKE_DUSK, 0.9))
	_overlay.draw_arc(ip, 25.0 * k, 0, TAU, 32, Color(UiKit.BRASS, 0.95), 3.0)
	var ic := Color(UiKit.LAMP)
	if e.get("locked", false):
		_overlay.draw_circle(ip + Vector2(0, -4) * k, 7.0 * k, ic)
		_overlay.draw_colored_polygon(PackedVector2Array([ip + Vector2(-5, -2) * k, ip + Vector2(5, -2) * k, ip + Vector2(8, 13) * k, ip + Vector2(-8, 13) * k]), ic)
	elif e.get("icon") == "door":
		_overlay.draw_arc(ip + Vector2(0, -2) * k, 10.0 * k, PI, TAU, 12, ic, 4.0)
		_overlay.draw_line(ip + Vector2(-10, -2) * k, ip + Vector2(-10, 14) * k, ic, 4.0)
		_overlay.draw_line(ip + Vector2(10, -2) * k, ip + Vector2(10, 14) * k, ic, 4.0)
		_overlay.draw_circle(ip + Vector2(5, 6) * k, 2.5 * k, ic)
	else:
		# footsteps: two small soles
		for sx in [-1.0, 1.0]:
			var c := ip + Vector2(sx * 6.0, -sx * 5.0) * k
			_overlay.draw_set_transform(c, 0.0, Vector2(1.0, 1.7))
			_overlay.draw_circle(Vector2.ZERO, 5.0 * k, ic)
			_overlay.draw_set_transform(Vector2.ZERO)
	# label plate below
	var text := str(e.get("label", ""))
	if text != "":
		var font := ThemeDB.fallback_font
		var fs := MARK_LABEL_FONT
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lp := p + Vector2(0, h * 0.5 + 10.0)
		var rect := Rect2(lp + Vector2(-tw * 0.5 - 16, 0), Vector2(tw + 32, fs + 16))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(UiKit.LAKE_DUSK, 0.88)
		sb.border_color = Color(UiKit.BRASS, 0.9 if pulse < 0.01 else 1.0)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(12)
		_overlay.draw_style_box(sb, rect)
		_overlay.draw_string(font, rect.position + Vector2(16, fs + 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiKit.IVORY)


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
