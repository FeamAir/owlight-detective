extends SceneTree
## Renders the slice 01 blockout (art_src/slice01_blockout.tscn):
##   - six 90° cube faces per viewpoint (camera at eye height, local frame: -Z = the viewpoint's yaw 0);
##   - the zone map (orthographic top view, north up);
##   - yaw/pitch/size_deg of every anchor from every viewpoint that sees it + occlusion check (ray cast).
## Output: <out>/<VP>_<face>.png, <out>/map.png, <out>/bake.json. The cube → equirect conversion and the
## YAML update are done by tools/pano_bake.py (called by tools/render_panos.sh).
##
## Run (needs a GPU context: xvfb + Mesa is enough):
##   xvfb-run -a godot --path game --rendering-driver opengl3 -s res://art_src/render_panos.gd -- --out=/abs/dir [--face=2048] [--only=VP-GATE-1] [--no-render]

const SCENE := "res://art_src/slice01_blockout.tscn"
# face name → [forward, up] in the viewpoint's local frame (forward -Z = yaw 0, right +X, up +Y)
const FACES := {
	"front": [Vector3(0, 0, -1), Vector3(0, 1, 0)],
	"right": [Vector3(1, 0, 0), Vector3(0, 1, 0)],
	"back": [Vector3(0, 0, 1), Vector3(0, 1, 0)],
	"left": [Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	"up": [Vector3(0, 1, 0), Vector3(0, 0, 1)],
	"down": [Vector3(0, -1, 0), Vector3(0, 0, -1)],
}
# map frame (world metres): x -50…22, z -90…16, 12 px per metre
const MAP_CENTER := Vector2(-14.0, -37.0)
const MAP_SIZE_M := Vector2(72.0, 106.0)
const MAP_PX_PER_M := 12.0

var out_dir := ""
var face_px := 2048
var only := ""
var no_render := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--face="):
			face_px = int(a.substr(7))
		elif a.begins_with("--only="):
			only = a.substr(7)
		elif a == "--no-render":
			no_render = true
	if out_dir == "":
		printerr("render_panos: --out=/abs/dir is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


static func local_yaw_pitch(eye: Vector3, heading: float, p: Vector3) -> Vector2:
	var d := p - eye
	var world_yaw := rad_to_deg(atan2(d.x, -d.z))
	var yaw := fposmod(world_yaw - heading, 360.0)
	var pitch := rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length()))
	return Vector2(yaw, pitch)


func _run() -> void:
	var sv := SubViewport.new()
	sv.size = Vector2i(face_px, face_px)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	sv.positional_shadow_atlas_size = 2048
	root.add_child(sv)
	var scene: Node3D = load(SCENE).instantiate()
	sv.add_child(scene)
	var cam := Camera3D.new()
	cam.fov = 90.0
	cam.near = 0.05
	cam.far = 3000.0
	sv.add_child(cam)
	cam.make_current()
	for i in 4:
		await physics_frame
	await process_frame

	var env: Environment = scene.get_node("WorldEnvironment").environment
	var base_ambient := env.ambient_light_energy
	var space := scene.get_world_3d().direct_space_state
	var bake := {"face_px": face_px, "viewpoints": {}, "anchors": {}}
	var anchors: Array = scene.get_node("Anchors").get_children()
	for a in anchors:
		bake["anchors"][a.get_meta("id")] = [a.global_position.x, a.global_position.y, a.global_position.z]
	var problems := 0
	for m in scene.get_node("Viewpoints").get_children():
		var vp_id := str(m.name)
		var heading := float(m.get_meta("heading"))
		var eye: Vector3 = m.global_position
		var entry := {"heading": heading, "eye": [eye.x, eye.y, eye.z], "interior": bool(m.get_meta("interior")), "anchors": {}}
		for a in anchors:
			if not (vp_id in a.get_meta("vps")):
				continue
			var p: Vector3 = a.global_position
			var yp := local_yaw_pitch(eye, heading, p)
			var dist := eye.distance_to(p)
			var r := float(a.get_meta("radius"))
			var size_deg := rad_to_deg(2.0 * atan(r / maxf(dist, 0.01)))
			var q := PhysicsRayQueryParameters3D.create(eye, p)
			var hit := space.intersect_ray(q)
			var occ := ""
			if not hit.is_empty() and eye.distance_to(hit["position"]) < dist - maxf(0.35, r * 0.8):
				occ = str(hit["collider"].get_parent().get_path()) if hit["collider"] else "?"
				problems += 1
				printerr("OCCLUDED: %s from %s by %s at %.1f m (anchor %.1f m)" % [a.get_meta("id"), vp_id, occ, eye.distance_to(hit["position"]), dist])
			entry["anchors"][a.get_meta("id")] = {"yaw": snappedf(yp.x, 0.1), "pitch": snappedf(yp.y, 0.1),
				"size_deg": snappedf(size_deg, 0.1), "dist": snappedf(dist, 0.1), "occluded_by": occ}
		bake["viewpoints"][vp_id] = entry
		if no_render or (only != "" and vp_id != only):
			continue
		env.ambient_light_energy = base_ambient * (0.42 if entry["interior"] else 1.0)
		env.fog_enabled = not entry["interior"]
		var rig := Basis(Vector3.UP, deg_to_rad(-heading))
		for face in FACES:
			var f: Vector3 = FACES[face][0]
			var u: Vector3 = FACES[face][1]
			var r3 := f.cross(u)
			cam.global_transform = Transform3D(rig * Basis(r3, u, -f), eye)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := sv.get_texture().get_image()
			img.save_png("%s/%s_%s.png" % [out_dir, vp_id, face])
		print("rendered ", vp_id)
	env.ambient_light_energy = base_ambient

	# zone map: orthographic, north up
	var map_px := Vector2i(int(MAP_SIZE_M.x * MAP_PX_PER_M), int(MAP_SIZE_M.y * MAP_PX_PER_M))
	sv.size = map_px
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = MAP_SIZE_M.y
	cam.global_transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3(MAP_CENTER.x, 120.0, MAP_CENTER.y))
	var map := {"size_px": [map_px.x, map_px.y], "center_m": [MAP_CENTER.x, MAP_CENTER.y], "px_per_m": MAP_PX_PER_M, "viewpoints": {}}
	for m in scene.get_node("Viewpoints").get_children():
		var g: Vector3 = m.global_position
		map["viewpoints"][str(m.name)] = {
			"u": snappedf((g.x - MAP_CENTER.x) / MAP_SIZE_M.x + 0.5, 0.0001),
			"v": snappedf((g.z - MAP_CENTER.y) / MAP_SIZE_M.y + 0.5, 0.0001),
			"heading": float(m.get_meta("heading"))}
	bake["map"] = map
	if not no_render and only == "":
		env.fog_enabled = false
		var sun: DirectionalLight3D = scene.get_node("Sun")
		sun.directional_shadow_max_distance = 200.0
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		sv.get_texture().get_image().save_png("%s/map.png" % out_dir)
		print("rendered map ", map_px)

	var fa := FileAccess.open("%s/bake.json" % out_dir, FileAccess.WRITE)
	fa.store_string(JSON.stringify(bake, "  ", false))
	fa.close()
	print("bake.json written; occlusion problems: ", problems)
	quit(0)
