class_name PanoMath
extends RefCounted
## Math of the 360° view. Pure functions, used by the panorama shader contract and unit tests.
##
## Angles (data contract, game/data/README.md):
##   yaw   0° = forward (entry direction of a viewpoint), grows clockwise seen from above (90° = right).
##   pitch up is positive, -90..90.
## World axes: forward = -Z, right = +X, up = +Y.
## Equirectangular image: u = 0.5 + yaw/360, v = 0.5 - pitch/180 (image centre = yaw 0).


static func wrap_yaw(yaw: float) -> float:
	var y := fmod(yaw, 360.0)
	if y < 0.0:
		y += 360.0
	return y


## Signed shortest difference b - a in degrees, -180..180.
static func yaw_delta(a: float, b: float) -> float:
	var d := fmod(b - a + 540.0, 360.0) - 180.0
	return d


static func dir_from(yaw_deg: float, pitch_deg: float) -> Vector3:
	var y := deg_to_rad(yaw_deg)
	var p := deg_to_rad(pitch_deg)
	return Vector3(sin(y) * cos(p), sin(p), -cos(y) * cos(p))


## Returns Vector2(yaw 0..360, pitch -90..90).
static func yaw_pitch_from(dir: Vector3) -> Vector2:
	var d := dir.normalized()
	var yaw := rad_to_deg(atan2(d.x, -d.z))
	var pitch := rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))
	return Vector2(wrap_yaw(yaw), pitch)


static func uv_from(yaw_deg: float, pitch_deg: float) -> Vector2:
	var y := yaw_deg
	if y > 180.0:
		y -= 360.0
	return Vector2(0.5 + y / 360.0, 0.5 - pitch_deg / 180.0)


## Camera basis [forward, right, up] for a camera looking at (yaw, pitch). No roll.
static func basis_for(cam_yaw: float, cam_pitch: float) -> Array:
	var f := dir_from(cam_yaw, cam_pitch)
	var r := dir_from(cam_yaw + 90.0, 0.0)
	var u := r.cross(f)
	return [f, r, u]


## Screen point → view direction. vfov — vertical field of view in degrees.
static func screen_to_dir(pos: Vector2, size: Vector2, cam_yaw: float, cam_pitch: float, vfov: float) -> Vector3:
	var b := basis_for(cam_yaw, cam_pitch)
	var t := tan(deg_to_rad(vfov) * 0.5)
	var aspect := size.x / maxf(size.y, 1.0)
	var nx := pos.x / size.x * 2.0 - 1.0
	var ny := 1.0 - pos.y / size.y * 2.0
	var d: Vector3 = b[0] + b[1] * (nx * t * aspect) + b[2] * (ny * t)
	return d.normalized()


## Direction → screen point. Returns {visible: bool, pos: Vector2}. "visible" = in front of the camera
## (the point may still be outside the screen rectangle).
static func dir_to_screen(dir: Vector3, size: Vector2, cam_yaw: float, cam_pitch: float, vfov: float) -> Dictionary:
	var b := basis_for(cam_yaw, cam_pitch)
	var z := dir.dot(b[0])
	if z <= 0.01:
		return {"visible": false, "pos": Vector2.ZERO}
	var t := tan(deg_to_rad(vfov) * 0.5)
	var aspect := size.x / maxf(size.y, 1.0)
	var nx := dir.dot(b[1]) / (z * t * aspect)
	var ny := dir.dot(b[2]) / (z * t)
	return {"visible": true, "pos": Vector2((nx + 1.0) * 0.5 * size.x, (1.0 - ny) * 0.5 * size.y)}


static func angular_distance(yaw_a: float, pitch_a: float, yaw_b: float, pitch_b: float) -> float:
	var a := dir_from(yaw_a, pitch_a)
	var b := dir_from(yaw_b, pitch_b)
	return rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))


## Pixels per degree near the screen centre.
static func px_per_degree(size: Vector2, vfov: float) -> float:
	return size.y / vfov
