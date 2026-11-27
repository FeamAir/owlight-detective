@tool
extends Node3D
## Slice 01 blockout: the whole outdoor zone + gatehouse interior from simple coloured shapes.
## Not part of the game (art_src/ is excluded from export). Rendered by art_src/render_panos.gd
## (game/tools/render_panos.sh) into 360° panoramas, the zone map and the yaw/pitch of every hotspot,
## overlay and transition mark (data/world/pano_anchors.yaml).
##
## Sources: docs/levels/slice-01-spec.md 3.1–3.5 (what is seen in each direction), docs/story/story-bible.md
## 7.1/7.4 (locations 1, 2, 17), docs/design/visual-and-ux.md 1.2 (palette «Латунь и туман»).
## Deliberately no detail or patterns (owner, 27.11): simple forms, readable colours, shadows and fog.
##
## World axes: X = east, -Z = north, Y = up, metres. Gate line z = 0, house to the north, lake to the west.
## Heading (world yaw) — clockwise from north seen from above, like the game's yaw.
##
## Anchors (Node3D "Anchors"): Marker3D named by the data id it positions; meta:
##   vps      — viewpoints that see it (yaw/pitch computed for each)
##   radius   — object radius in metres → size_deg of the hotspot / overlay
## Viewpoints (Node3D "Viewpoints"): Marker3D at eye height (1.55 m above ground), meta heading, interior.

const EYE := 1.55
const WATER_Y := -7.0

# palette (visual-and-ux 1.2) + a few blockout neutrals
const LAKE_DUSK := Color("#1E2A33")
const WALNUT := Color("#3A2A20")
const BRASS := Color("#C08F45")
const LAMP := Color("#F2C98A")
const IVORY := Color("#EEE4CF")
const INK := Color("#24313F")
const MAPLE := Color("#A4472F")
const MOSS := Color("#5F6B3B")
const FOG := Color("#93A6AB")
const GRASS := Color("#5E6A3E")
const GRASS_DRY := Color("#7A7444")
const GRAVEL := Color("#9A9284")
const GRAVEL_DARK := Color("#6E675C")
const ROAD := Color("#7C7568")
const STONE := Color("#9C978C")
const STONE_DARK := Color("#77736B")
const BRICK := Color("#8A4B3A")
const PLASTER := Color("#A89B88")
const SLATE := Color("#454C55")
const IRON := Color("#2A2E33")
const OAK_LEAF := Color("#6E6233")
const LINDEN := Color("#C39A3E")
const BARK := Color("#4A3B2E")
const HEDGE := Color("#3F4A2C")
const WATER := Color("#4F646C")
const PLANK := Color("#6B5440")
const PLANK_WET := Color("#4E3E30")

var _mats := {}
var _geo: Node3D
var _anchors: Node3D
var _vps: Node3D


func _ready() -> void:
	build()


func build() -> void:
	for c in get_children():
		c.free()
	_mats.clear()
	_geo = _node("Geometry")
	_anchors = _node("Anchors")
	_vps = _node("Viewpoints")
	_environment()
	_terrain()
	_ground_paths()
	_gate_and_fence()
	_gatehouse()
	_alley_trees()
	_forecourt_and_fountain()
	_house()
	_garden_gate()
	_lake_and_pier()
	_trees_around()
	_hills()
	_viewpoints()


func _node(n: String) -> Node3D:
	var x := Node3D.new()
	x.name = n
	add_child(x)
	return x


# ------------------------------------------------------------------ terrain height

## Ground height. Plateau y = 0 for the estate; road to the station descends south; to the west the
## slope goes down to the lake (water at y = -7). The brow of the slope (x ≈ -12) hides the pier from the alley
## (story-bible 6.2: «с аллеи мостки скрыты склоном и утренним туманом»).
static func h(x: float, z: float) -> float:
	var y := 0.0
	if z > 14.0:
		y -= minf((z - 14.0) * 0.07, 6.0)
	var s := -12.0 - x
	var shore := 21.0 + 3.0 * sin(z / 19.0)
	if s > 0.0:
		if s < shore:
			y += -7.4 * smoothstep(0.0, shore, s)
		else:
			y += -7.4 - minf(3.0, (s - shore) * 0.2)
	return y


func _gp(x: float, z: float, up: float = 0.0) -> Vector3:
	return Vector3(x, h(x, z) + up, z)


# ------------------------------------------------------------------ primitives

func _mat(c: Color, emission: float = 0.0, rough: float = 0.92) -> StandardMaterial3D:
	var key := "%s/%.2f/%.2f" % [c.to_html(), emission, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


func _mesh(mesh: Mesh, xf: Transform3D, c: Color, emission: float = 0.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.transform = xf
	mi.material_override = _mat(c, emission)
	(parent if parent else _geo).add_child(mi)
	return mi


func _solid(shape: Shape3D, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.transform = xf
	body.add_child(cs)
	_geo.add_child(body)


## Box by centre and size; rot_y in degrees (heading-style: clockwise from above).
func box(center: Vector3, sz: Vector3, c: Color, rot_y: float = 0.0, solid: bool = true, emission: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = sz
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-rot_y)), center)
	if solid:
		var s := BoxShape3D.new()
		s.size = sz
		_solid(s, xf)
	return _mesh(m, xf, c, emission)


## Vertical cylinder standing on base (centre of the bottom face).
func cyl(base: Vector3, r: float, height: float, c: Color, solid: bool = true, segs: int = 16, r_top: float = -1.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r if r_top < 0.0 else r_top
	m.bottom_radius = r
	m.height = height
	m.radial_segments = segs
	m.rings = 1
	var xf := Transform3D(Basis(), base + Vector3(0, height * 0.5, 0))
	if solid:
		var s := CylinderShape3D.new()
		s.radius = r
		s.height = height
		_solid(s, xf)
	return _mesh(m, xf, c)


## Thin disc facing a heading (medallions, clock faces).
func disc(center: Vector3, r: float, thick: float, facing_heading: float, c: Color, emission: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = thick
	m.radial_segments = 24
	m.rings = 1
	var b := Basis(Vector3.UP, deg_to_rad(-facing_heading)) * Basis(Vector3.RIGHT, deg_to_rad(-90))
	return _mesh(m, Transform3D(b, center), c, emission)


func ellipsoid(center: Vector3, radii: Vector3, c: Color, solid: bool = false) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 14
	m.rings = 8
	var xf := Transform3D(Basis.from_scale(radii * 2.0), center)
	if solid:
		var s := SphereShape3D.new()
		s.radius = minf(radii.x, minf(radii.y, radii.z))
		_solid(s, Transform3D(Basis(), center))
	return _mesh(m, xf, c)


## Gable roof: ridge along Z (north–south) for rot_y 0 (rot_y turns it), base at y0.
func gable(center_base: Vector3, length: float, depth: float, height: float, c: Color, rot_y: float = 0.0) -> void:
	var m := PrismMesh.new()
	m.size = Vector3(depth, height, length)
	var b := Basis(Vector3.UP, deg_to_rad(-rot_y))
	var xf := Transform3D(b, center_base + Vector3(0, height * 0.5, 0))
	_mesh(m, xf, c)
	var s := BoxShape3D.new()
	s.size = Vector3(depth * 0.6, height * 0.6, length)
	_solid(s, xf)


## Hip-ish roof for big blocks: a flattened pyramid (cylinder with 4 segments, rotated 45°).
func hip(center_base: Vector3, sx: float, sz: float, height: float, c: Color) -> void:
	var m := CylinderMesh.new()
	m.bottom_radius = 0.7071
	m.top_radius = 0.18
	m.height = 1.0
	m.radial_segments = 4
	m.rings = 1
	var b := Basis.from_scale(Vector3(sx, height, sz)) * Basis(Vector3.UP, deg_to_rad(45))
	_mesh(m, Transform3D(b, center_base + Vector3(0, height * 0.5, 0)), c)


func anchor(id: String, pos: Vector3, vps: Array, radius: float) -> void:
	var a := Marker3D.new()
	a.name = id.replace(":", "_").replace(">", "_")
	a.position = pos
	a.set_meta("id", id)
	a.set_meta("vps", vps)
	a.set_meta("radius", radius)
	_anchors.add_child(a)


## Transition mark on the ground (id "exit:<from>><to>").
func exit_mark(from_vp: String, to_vp: String, x: float, z: float, up: float = 0.0) -> void:
	anchor("exit:%s>%s" % [from_vp, to_vp], _gp(x, z, up), [from_vp], 0.6)


# ------------------------------------------------------------------ environment

func _environment() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#8D9CA4")
	sm.sky_horizon_color = Color("#C9CFCD")
	sm.ground_horizon_color = Color("#B8BDB8")
	sm.ground_bottom_color = Color("#6B6F66")
	sm.sky_curve = 0.12
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#B9C2C2")
	env.fog_light_energy = 1.0
	env.fog_density = 0.0065
	env.fog_sky_affect = 0.55
	env.fog_aerial_perspective = 0.0
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("#FFF4E6")
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.shadow_blur = 2.5
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-38, 150, 0)     # overcast morning, sun low in the south-east
	add_child(sun)


# ------------------------------------------------------------------ terrain

func _terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -220.0
	var x1 := 160.0
	var z0 := -230.0
	var z1 := 200.0
	var step := 2.0
	var nx := int((x1 - x0) / step)
	var nz := int((z1 - z0) / step)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var cols := {}
	for i in nx + 1:
		for j in nz + 1:
			var x := x0 + i * step
			var z := z0 + j * step
			var y := h(x, z)
			var n := 0.5 + 0.5 * sin(x * 0.21 + z * 0.13) * cos(z * 0.17 - x * 0.05)
			var c := GRASS.lerp(GRASS_DRY, n * 0.55 + rng.randf() * 0.1)
			if y < -5.6:          # muddy shore, then lake bed
				c = c.lerp(Color("#5B5446"), clampf((-5.6 - y) / 1.2, 0.0, 1.0))
			cols[Vector2i(i, j)] = [Vector3(x, y, z), c]
	for i in nx:
		for j in nz:
			var q := [cols[Vector2i(i, j)], cols[Vector2i(i + 1, j)], cols[Vector2i(i + 1, j + 1)], cols[Vector2i(i, j + 1)]]
			tri(st, q[0], q[1], q[2])
			tri(st, q[0], q[2], q[3])
	st.generate_normals()
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = m
	_geo.add_child(mi)
	mi.create_trimesh_collision()
	# far ground ring so the horizon is never empty (fog hides the seam)
	var far := PlaneMesh.new()
	far.size = Vector2(4000, 4000)
	_mesh(far, Transform3D(Basis(), Vector3(2158, -0.6, 0)), Color("#5A6242"))
	# lake
	var wm := PlaneMesh.new()
	wm.size = Vector2(3000, 3000)
	var w := _mesh(wm, Transform3D(Basis(), Vector3(-1520, WATER_Y, 0)), WATER)
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = WATER
	wmat.roughness = 0.45
	wmat.metallic_specular = 0.35
	w.material_override = wmat
	var wm2 := PlaneMesh.new()
	wm2.size = Vector2(240, 600)
	var w2 := _mesh(wm2, Transform3D(Basis(), Vector3(-140, WATER_Y, 0)), WATER)
	w2.material_override = wmat


## Adds an upward-facing triangle (Godot front faces are clockwise seen from the front). v = [Vector3, Color].
static func tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	var n: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	var order := [a, b, c] if n.y < 0.0 else [a, c, b]
	for v in order:
		st.set_color(v[1].srgb_to_linear())     # compatibility renderer reads vertex colours as linear
		st.add_vertex(v[0])


## Draped strip along a polyline of (x, z) points.
func strip(points: Array, width: float, c: Color, up: float = 0.03, c2: Color = Color(0, 0, 0, 0)) -> void:
	var pts: Array = []
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 0.8))
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	pts.append(points[-1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width * 100) + points.size()
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := c
	for i in pts.size():
		var p: Vector2 = pts[i]
		var d: Vector2 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-d.y, d.x) * width * 0.5
		var l := _gp(p.x + nrm.x, p.y + nrm.y, up)
		var r := _gp(p.x - nrm.x, p.y - nrm.y, up)
		var cc := c if c2.a == 0.0 else c.lerp(c2, rng.randf())
		if i > 0:
			tri(st, [prev_l, prev_c], [r, cc], [prev_r, prev_c])
			tri(st, [prev_l, prev_c], [l, cc], [r, cc])
		prev_l = l
		prev_r = r
		prev_c = cc
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	_geo.add_child(mi)


## Flat polygon patch on the plateau (y = 0 area only).
func patch(poly: PackedVector2Array, c: Color, up: float = 0.025) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for t in range(0, idx.size(), 3):
		var v: Array = []
		for k in 3:
			var p := poly[idx[t + k]]
			v.append([_gp(p.x, p.y, up), c])
		tri(st, v[0], v[1], v[2])
	st.generate_normals()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	_geo.add_child(mi)


func _ground_paths() -> void:
	# road from the station: comes up from the south along the lake, straight into the gate
	strip([Vector2(-26, 200), Vector2(-14, 120), Vector2(-4, 60), Vector2(0, 30), Vector2(0, 0.5)], 5.2, ROAD, 0.03, ROAD.darkened(0.12))
	# the drive (alley) gate → forecourt
	strip([Vector2(0, 0.5), Vector2(0, -45)], 5.0, GRAVEL, 0.035, GRAVEL.darkened(0.1))
	# forecourt in front of the house (between the wings)
	patch(PackedVector2Array([Vector2(-5.5, -44.5), Vector2(9.0, -44.5), Vector2(9.0, -72), Vector2(-5.5, -72)]), GRAVEL)
	# fresh tyre tracks along the drive and across the mouth of the fork (spec 3.4: 255–265°)
	for off in [-0.85, 0.85]:
		strip([Vector2(off, 6), Vector2(off, -44), Vector2(off * 0.6 - 2.5, -58), Vector2(off * 0.6 - 2.5, -62)], 0.16, GRAVEL.darkened(0.22), 0.05)
	# the fork: gravel path down to the lake (ALLEY-01)
	strip([Vector2(-2.0, -45.0), Vector2(-8, -46), Vector2(-13, -45.5), Vector2(-17, -43.5), Vector2(-21, -40),
		Vector2(-24, -36.5), Vector2(-26.6, -33.0)], 1.7, GRAVEL_DARK, 0.04, GRAVEL)
	# a wider gravel apron where the path leaves the drive (the gravel hotspot)
	patch(PackedVector2Array([Vector2(-2.6, -43.2), Vector2(-6.0, -44.2), Vector2(-6.2, -47.4), Vector2(-2.6, -46.8)]), GRAVEL_DARK.lightened(0.08), 0.045)
	# path to the garden gate
	strip([Vector2(2.5, -43.5), Vector2(9, -41.2), Vector2(18, -41.2)], 1.6, GRAVEL)


# ------------------------------------------------------------------ gate, pillars, fence

const PILLAR_X := [-5.4, -1.9, 1.9, 5.4]


func _fence_run(xa: float, xb: float, z: float) -> void:
	var y := 0.0
	box(Vector3((xa + xb) * 0.5, 0.25, z), Vector3(absf(xb - xa), 0.5, 0.35), STONE_DARK)
	box(Vector3((xa + xb) * 0.5, 2.05, z), Vector3(absf(xb - xa), 0.07, 0.07), IRON, 0.0, false)
	box(Vector3((xa + xb) * 0.5, 0.75, z), Vector3(absf(xb - xa), 0.06, 0.06), IRON, 0.0, false)
	var n := int(absf(xb - xa) / 0.22)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bar := BoxMesh.new()
	bar.size = Vector3(0.035, 1.85, 0.035)
	mm.mesh = bar
	mm.instance_count = n
	for i in n:
		var x := xa + (i + 0.5) * (xb - xa) / n
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(x, y + 0.5 + 0.92, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _mat(IRON)
	_geo.add_child(mmi)
	# posts every 3 m
	var posts := int(absf(xb - xa) / 3.0)
	for i in posts + 1:
		var x := xa + i * (xb - xa) / maxf(1, posts)
		box(Vector3(x, 1.2, z), Vector3(0.09, 2.4, 0.09), IRON, 0.0, false)


func _gate_and_fence() -> void:
	# four stone pillars with cast-iron medallions (spec 3.2: yaw −40…+40°); signs are drawn by the game
	for i in 4:
		var x: float = PILLAR_X[i]
		box(Vector3(x, 2.0, 0), Vector3(1.1, 4.0, 1.1), STONE)
		box(Vector3(x, 4.1, 0), Vector3(1.35, 0.25, 1.35), STONE_DARK)
		ellipsoid(Vector3(x, 4.45, 0), Vector3(0.35, 0.3, 0.35), STONE_DARK)
		var mc := Vector3(x, 3.15, 0.58)
		disc(mc, 0.5, 0.06, 180.0, IRON)
		disc(mc + Vector3(0, 0, 0.02), 0.44, 0.06, 180.0, Color("#3A3A3A"))
		anchor("medallion_%d" % (i + 1), mc + Vector3(0, 0, 0.05), ["VP-GATE-1"], 0.5)
	# open wrought-iron gate leaves, swung inwards
	for side in [-1, 1]:
		var hinge := Vector3(side * 1.35, 0, -0.1)
		var ang: float = 20.0 if side < 0 else 340.0      # closed: pointing to the middle; open 70° inwards
		var leaf_len := 1.35
		var dirv := Vector3(sin(deg_to_rad(ang)), 0, -cos(deg_to_rad(ang)))
		var heading := ang
		for k in 7:
			var p := hinge + dirv * (leaf_len * (k + 0.5) / 7.0)
			box(p + Vector3(0, 1.3, 0), Vector3(0.04, 2.4, 0.04), IRON, 0.0, false)
		var mid := hinge + dirv * leaf_len * 0.5
		box(mid + Vector3(0, 2.45, 0), Vector3(leaf_len, 0.08, 0.06), IRON, heading - 90.0, false)
		box(mid + Vector3(0, 0.35, 0), Vector3(leaf_len, 0.08, 0.06), IRON, heading - 90.0, false)
	# fence between the pillars and along the road
	_fence_run(-4.85, -2.45, 0)
	_fence_run(2.45, 4.85, 0)
	_fence_run(-28.0, -5.95, 0)
	_fence_run(11.5, 46.0, 0)
	anchor("HS-GATE-PILLARS", Vector3(0, 2.6, 0), ["VP-GATE-1"], 6.2)
	anchor("HS-GATE-ROAD", _gp(0, 24, 0.5), ["VP-GATE-1"], 5.0)
	exit_mark("VP-GATE-1", "VP-ALLEY-1", 0.0, 4.6)


# ------------------------------------------------------------------ gatehouse (exterior + interior)

const GH_X0 := 6.5
const GH_X1 := 11.5
const GH_Z0 := -3.0
const GH_Z1 := 3.5
const GH_WALL := 0.3
const GH_H := 3.0
const GH_DOOR_Z := 1.6


func _gatehouse() -> void:
	var t := GH_WALL
	var cx := (GH_X0 + GH_X1) * 0.5
	var cz := (GH_Z0 + GH_Z1) * 0.5
	var wx := GH_X1 - GH_X0
	var wz := GH_Z1 - GH_Z0
	# north and east walls (solid)
	box(Vector3(cx, GH_H * 0.5, GH_Z0 + t * 0.5), Vector3(wx, GH_H, t), BRICK)
	box(Vector3(GH_X1 - t * 0.5, GH_H * 0.5, cz), Vector3(t, GH_H, wz), BRICK)
	# west wall with the door (door 1.0 × 2.1 at z = GH_DOOR_Z)
	var dz0 := GH_DOOR_Z - 0.5
	var dz1 := GH_DOOR_Z + 0.5
	box(Vector3(GH_X0 + t * 0.5, GH_H * 0.5, (GH_Z0 + dz0) * 0.5), Vector3(t, GH_H, dz0 - GH_Z0), BRICK)
	box(Vector3(GH_X0 + t * 0.5, GH_H * 0.5, (dz1 + GH_Z1) * 0.5), Vector3(t, GH_H, GH_Z1 - dz1), BRICK)
	box(Vector3(GH_X0 + t * 0.5, (2.1 + GH_H) * 0.5, GH_DOOR_Z), Vector3(t, GH_H - 2.1, 1.0), BRICK)
	# door: closed, walnut, brass code-lock plate (HS-GATE-LOCK)
	box(Vector3(GH_X0 + 0.05, 1.05, GH_DOOR_Z), Vector3(0.08, 2.1, 1.0), WALNUT)
	box(Vector3(GH_X0 - 0.03, 1.12, GH_DOOR_Z - 0.3), Vector3(0.04, 0.34, 0.22), BRASS, 0.0, false, 0.15)
	box(Vector3(GH_X0 + 0.12, 1.05, GH_DOOR_Z), Vector3(0.04, 2.1, 1.0), Color("#4A372A"), 0.0, false)   # inner face
	anchor("HS-GATE-LOCK", Vector3(GH_X0 - 0.06, 1.12, GH_DOOR_Z - 0.3), ["VP-GATE-1"], 0.45)
	box(Vector3(GH_X0 - 0.35, 0.08, GH_DOOR_Z), Vector3(0.6, 0.16, 1.3), STONE_DARK)  # step
	# south wall with a window (outside: closed shutters; inside the inner shutter is open → light)
	var wx0 := 9.2
	var wx1 := 10.6
	box(Vector3((GH_X0 + wx0) * 0.5, GH_H * 0.5, GH_Z1 - t * 0.5), Vector3(wx0 - GH_X0, GH_H, t), BRICK)
	box(Vector3((wx1 + GH_X1) * 0.5, GH_H * 0.5, GH_Z1 - t * 0.5), Vector3(GH_X1 - wx1, GH_H, t), BRICK)
	box(Vector3((wx0 + wx1) * 0.5, 0.5, GH_Z1 - t * 0.5), Vector3(wx1 - wx0, 1.0, t), BRICK)
	box(Vector3((wx0 + wx1) * 0.5, 2.55, GH_Z1 - t * 0.5), Vector3(wx1 - wx0, 0.9, t), BRICK)
	box(Vector3((wx0 + wx1) * 0.5, 1.55, GH_Z1 - 0.15), Vector3(wx1 - wx0, 1.1, 0.04), Color("#C9D6D8"), 0.0, true, 0.55)  # pane (bright day)
	for sx in [wx0 - 0.36, wx1 + 0.36]:
		box(Vector3(sx, 1.55, GH_Z1 + 0.05), Vector3(0.7, 1.2, 0.05), MOSS.darkened(0.2), 0.0, false)
	box(Vector3((wx0 + wx1) * 0.5, 1.55, GH_Z1 + 0.04), Vector3(wx1 - wx0, 1.15, 0.04), MOSS.darkened(0.25), 0.0, false)  # closed shutters outside
	# floor, ceiling, roof, chimney
	box(Vector3(cx, 0.03, cz), Vector3(wx - 2 * t, 0.06, wz - 2 * t), PLANK)
	box(Vector3(cx, GH_H - 0.05, cz), Vector3(wx, 0.1, wz), Color("#6A5A48"))
	gable(Vector3(cx, GH_H, cz), wz + 0.6, wx + 0.6, 1.7, SLATE, 0.0)
	box(Vector3(7.4, GH_H + 1.4, 2.6), Vector3(0.5, 1.8, 0.5), BRICK.darkened(0.15))
	# --- interior (VP-GATE-2): facing east from the door; keybox ahead on the east wall
	var ix1 := GH_X1 - t
	var iz0 := GH_Z0 + t
	var iz1 := GH_Z1 - t
	# inner plaster faces (slightly inside the brick so they win)
	box(Vector3(cx, GH_H * 0.5, iz0 + 0.01), Vector3(wx - 2 * t, GH_H, 0.02), PLASTER, 0.0, false)
	box(Vector3(ix1 - 0.01, GH_H * 0.5, cz), Vector3(0.02, GH_H, wz - 2 * t), PLASTER, 0.0, false)
	# keybox: dark oak, glass door, brass dial, white tag on the handle (HS-GATE-KEYBOX)
	var kb := Vector3(ix1 - 0.09, 1.5, GH_DOOR_Z)
	box(kb, Vector3(0.16, 0.9, 0.7), WALNUT)
	box(kb + Vector3(-0.09, 0.08, 0), Vector3(0.02, 0.6, 0.56), Color("#8FA3A8"), 0.0, false, 0.15)
	disc(kb + Vector3(-0.1, -0.32, 0), 0.09, 0.02, 270.0, BRASS, 0.2)
	box(kb + Vector3(-0.11, -0.05, -0.31), Vector3(0.02, 0.12, 0.07), IVORY, 0.0, false, 0.3)
	anchor("HS-GATE-KEYBOX", kb + Vector3(-0.1, 0, 0), ["VP-GATE-2"], 0.42)
	# lamp over the keybox
	box(Vector3(ix1 - 0.2, 2.25, GH_DOOR_Z), Vector3(0.18, 0.12, 0.18), LAMP, 0.0, false, 3.0)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(ix1 - 0.45, 2.2, GH_DOOR_Z)
	lamp.light_color = LAMP
	lamp.light_energy = 1.6
	lamp.omni_range = 4.5
	_geo.add_child(lamp)
	# table under the window: weather recorder under a glass dome + open weather log, stool
	var tc := Vector3(9.9, 0.0, iz1 - 0.4)
	box(tc + Vector3(0, 0.74, 0), Vector3(1.5, 0.06, 0.7), PLANK.lightened(0.1))
	for lx in [-0.68, 0.68]:
		for lz in [-0.28, 0.28]:
			box(tc + Vector3(lx, 0.36, lz), Vector3(0.06, 0.72, 0.06), PLANK, 0.0, false)
	cyl(tc + Vector3(-0.32, 0.77, 0.05), 0.2, 0.06, WALNUT, false)
	cyl(tc + Vector3(-0.32, 0.83, 0.05), 0.09, 0.2, BRASS, false)
	cyl(tc + Vector3(-0.32, 0.83, 0.05), 0.18, 0.38, Color("#B8CACC"), false, 16, 0.12)
	anchor("HS-GATE-WEATHERREC", tc + Vector3(-0.32, 0.98, 0.05), ["VP-GATE-2"], 0.3)
	box(tc + Vector3(0.38, 0.785, -0.02), Vector3(0.46, 0.02, 0.32), IVORY, 0.0, false, 0.25)
	anchor("HS-GATE-WEATHERLOG", tc + Vector3(0.38, 0.8, -0.02), ["VP-GATE-2"], 0.27)
	cyl(Vector3(9.4, 0, iz1 - 1.05), 0.17, 0.48, PLANK, false)
	var win := OmniLight3D.new()
	win.position = Vector3(9.9, 1.7, iz1 - 0.6)
	win.light_color = Color("#DDE6EA")
	win.light_energy = 1.4
	win.omni_range = 4.0
	_geo.add_child(win)
	# wall clock (hard only): not baked into the picture — the game draws it (overlay "wallclock")
	anchor("wallclock", Vector3(8.15, 2.05, iz1 - 0.04), ["VP-GATE-2"], 0.17)
	anchor("HS-GATE-WALLCLOCK", Vector3(8.15, 2.05, iz1 - 0.04), ["VP-GATE-2"], 0.25)
	# stove by the door
	box(Vector3(7.25, 0.45, 2.55), Vector3(0.6, 0.9, 0.6), IRON.lightened(0.08))
	cyl(Vector3(7.25, 0.9, 2.55), 0.07, 2.0, IRON, false)
	# gate recorder on a cabinet (HS-GATE-RECORDER): drum with paper tape, one pen
	var rc := Vector3(10.6, 0, -1.05)
	box(rc + Vector3(0, 0.42, 0), Vector3(0.6, 0.84, 0.5), WALNUT.lightened(0.08))
	var drum := cyl(rc + Vector3(0, 0.86, 0), 0.12, 0.26, IVORY, false)
	drum.material_override = _mat(IVORY, 0.2)
	cyl(rc + Vector3(0.16, 0.86, 0), 0.03, 0.28, BRASS, false)
	anchor("HS-GATE-RECORDER", rc + Vector3(0, 0.98, 0), ["VP-GATE-2"], 0.3)
	# coat hooks, shelf — a bit of life
	box(Vector3(cx, 1.9, iz0 + 0.12), Vector3(1.4, 0.04, 0.22), PLANK, 0.0, false)
	exit_mark("VP-GATE-1", "VP-GATE-2", 4.4, 3.4)
	anchor("exit:VP-GATE-2>VP-GATE-1", Vector3(GH_X0 + 0.2, 0.9, GH_DOOR_Z), ["VP-GATE-2"], 0.5)


# ------------------------------------------------------------------ trees

func tree(x: float, z: float, height: float, crown: float, leaf: Color, solid: bool = true) -> void:
	var base := _gp(x, z, -0.1)
	cyl(base, 0.22 * height / 8.0 + 0.08, height * 0.65, BARK, solid, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(x * 131.0 + z * 17.0))
	for k in 3:
		var off := Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5)) * crown
		var r := crown * rng.randf_range(0.62, 0.8)
		var c := leaf.lerp(leaf.darkened(0.25), rng.randf())
		ellipsoid(base + Vector3(0, height * 0.62 + k * crown * 0.35, 0) + off, Vector3(r, r * 0.85, r), c, solid and k == 0)


func _alley_trees() -> void:
	var z := -4.5
	var i := 0
	while z > -42.0:
		var leaf := LINDEN if i % 3 != 1 else MAPLE.lightened(0.1)
		tree(-4.6, z, 8.0, 2.3, leaf)
		tree(4.6, z - 1.0, 8.0, 2.3, LINDEN if i % 3 != 2 else MAPLE.lightened(0.1))
		z -= 7.0
		i += 1
	# fallen leaves under the trees
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 90:
		var px := rng.randf_range(-7.0, 7.0)
		if absf(px) < 2.4:
			px = signf(px) * 2.6 + px * 0.2
		var pz := rng.randf_range(-42.0, -2.0)
		var lc := LINDEN if rng.randf() < 0.65 else MAPLE
		box(_gp(px, pz, 0.03), Vector3(rng.randf_range(0.3, 0.8), 0.01, rng.randf_range(0.3, 0.8)), lc.darkened(0.1), rng.randf() * 90.0, false)


func _trees_around() -> void:
	# old oaks west of the gate (spec 3.2, 270°)
	for p in [Vector2(-10, -4), Vector2(-16, -7), Vector2(-23, -3.5), Vector2(-30, -8), Vector2(-37, -4), Vector2(-13, -14),
			Vector2(-20, -18), Vector2(-27, -16)]:
		tree(p.x, p.y, 10.0, 3.6, OAK_LEAF)
	# maples east of the gatehouse (spec 3.2, 90°)
	for p in [Vector2(14.5, -5), Vector2(19, -3.5), Vector2(24, -7), Vector2(30, -4), Vector2(36, -8), Vector2(17, -12),
			Vector2(26, -15)]:
		tree(p.x, p.y, 8.5, 2.8, MAPLE)
	# outside the fence along the road
	for p in [Vector2(-9, 8), Vector2(9, 12), Vector2(-12, 24), Vector2(12, 28), Vector2(16, 18)]:
		tree(p.x, p.y, 9.0, 3.0, OAK_LEAF.lerp(MAPLE, 0.3))
	# behind the house and along the slope to the lake
	for p in [Vector2(-22, -60), Vector2(-26, -70), Vector2(-18, -86), Vector2(0, -95), Vector2(20, -95), Vector2(28, -70),
			Vector2(32, -50), Vector2(-30, -52), Vector2(-12, -30), Vector2(-20, -26), Vector2(-8, -22), Vector2(-33, -12)]:
		tree(p.x, p.y, 10.0, 3.4, OAK_LEAF if int(p.x) % 2 == 0 else LINDEN.darkened(0.15))
	# shore willows-ish near the pier (keep the view along the pier free)
	for p in [Vector2(-25, -56), Vector2(-34, -45)]:
		tree(p.x, p.y, 7.0, 2.6, MOSS.lightened(0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 70:
		var px := rng.randf_range(10.0, 38.0)
		var pz := rng.randf_range(-16.0, -1.0)
		box(_gp(px, pz, 0.03), Vector3(rng.randf_range(0.3, 0.7), 0.01, rng.randf_range(0.3, 0.7)), MAPLE, rng.randf() * 90.0, false)


# ------------------------------------------------------------------ forecourt, fountain, house

func _forecourt_and_fountain() -> void:
	var f := Vector3(0, 0, -52)
	# basin with 4 bowls around the owl (spec 3.4: owl on a pedestal, 4 bowls)
	cyl(f, 2.6, 0.55, STONE)
	cyl(f + Vector3(0, 0.55, 0), 2.35, 0.02, WATER.darkened(0.15), false, 24)
	cyl(f, 0.42, 1.0, STONE_DARK)
	for k in 4:
		var a := deg_to_rad(45.0 + 90.0 * k)
		var bp := f + Vector3(sin(a), 0, -cos(a)) * 1.5
		cyl(bp, 0.12, 0.85, STONE_DARK, false, 8)
		cyl(bp + Vector3(0, 0.85, 0), 0.24, 0.16, STONE, false, 16, 0.48)
	# the owl: body, head, ear tufts, two pale eyes (one owl per frame — visual-and-ux 1.1)
	ellipsoid(f + Vector3(0, 1.28, 0), Vector3(0.3, 0.36, 0.27), STONE.lightened(0.05), true)
	ellipsoid(f + Vector3(0, 1.72, 0), Vector3(0.24, 0.2, 0.22), STONE.lightened(0.05))
	for sx in [-0.13, 0.13]:
		box(f + Vector3(sx, 1.92, 0), Vector3(0.07, 0.14, 0.06), STONE, sx * 120.0, false)
		disc(f + Vector3(sx * 0.75, 1.74, 0.2), 0.055, 0.02, 180.0, IVORY.darkened(0.1))
	anchor("HS-ALLEY-FOUNTAIN", f + Vector3(0, 0.8, 0), ["VP-ALLEY-1"], 2.6)
	# old car parked by the west wing (Martha came back with Clara)
	var car := Vector3(-3.3, 0, -61.0)
	box(car + Vector3(0, 0.6, 0), Vector3(1.7, 0.7, 4.0), Color("#2C3B35"))
	box(car + Vector3(0, 1.25, 0.3), Vector3(1.5, 0.6, 2.0), Color("#2C3B35").darkened(0.1))
	for wxz in [Vector2(-0.85, -1.3), Vector2(0.85, -1.3), Vector2(-0.85, 1.3), Vector2(0.85, 1.3)]:
		var wb := car + Vector3(wxz.x, 0.36, wxz.y)
		var wm := CylinderMesh.new()
		wm.top_radius = 0.36
		wm.bottom_radius = 0.36
		wm.height = 0.2
		_mesh(wm, Transform3D(Basis(Vector3.FORWARD, deg_to_rad(90)), wb), IRON)


func _window_row(x0: float, x1: float, z: float, y: float, n: int, facing: float, lit: Array = []) -> void:
	for i in n:
		var x := x0 + (i + 0.5) * (x1 - x0) / n
		var is_lit := i in lit
		var c := LAMP if is_lit else Color("#3B4650")
		var e := 1.6 if is_lit else 0.0
		var off := 0.06 if facing == 180.0 else -0.06
		box(Vector3(x, y, z + off), Vector3(1.0, 1.6, 0.06), IVORY.darkened(0.15), 0.0, false)
		box(Vector3(x, y, z + off * 1.6), Vector3(0.82, 1.42, 0.04), c, 0.0, false, e)


func _window_col(x: float, z0: float, z1: float, y: float, n: int, lit: Array = []) -> void:
	for i in n:
		var z := z0 + (i + 0.5) * (z1 - z0) / n
		var is_lit := i in lit
		var c := LAMP if is_lit else Color("#3B4650")
		box(Vector3(x - 0.06, y, z), Vector3(0.06, 1.6, 1.0), IVORY.darkened(0.15), 0.0, false)
		box(Vector3(x - 0.1, y, z), Vector3(0.04, 1.42, 0.82), c, 0.0, false, 1.6 if is_lit else 0.0)


func _house() -> void:
	# main block: south facade z = -72, front door in the middle (HS-ALLEY-FRONTDOOR)
	box(Vector3(0, 4.5, -78), Vector3(30, 9.0, 12), PLASTER)
	box(Vector3(0, 0.4, -71.9), Vector3(30.4, 0.8, 0.2), STONE_DARK, 0.0, false)
	hip(Vector3(0, 9.0, -78), 31.0, 13.0, 4.0, SLATE)
	box(Vector3(-6, 13.6, -78), Vector3(0.9, 2.0, 0.9), BRICK.darkened(0.1))
	box(Vector3(7, 13.6, -79), Vector3(0.9, 2.0, 0.9), BRICK.darkened(0.1))
	_window_row(-15, -2, -72, 2.6, 5, 180.0, [1])
	_window_row(2, 15, -72, 2.6, 5, 180.0, [])
	_window_row(-15, 15, -72, 6.6, 11, 180.0, [3, 8])
	# porch: steps, two columns, small roof, lantern; walnut double door
	for k in 3:
		box(Vector3(0, 0.15 + k * 0.3, -70.2 + k * 0.5 - 0.5), Vector3(4.0 - k * 0.3, 0.3, 1.0), STONE)
	box(Vector3(0, 0.85, -71.3), Vector3(3.6, 0.1, 1.6), STONE_DARK, 0.0, false)
	for sx in [-1.6, 1.6]:
		cyl(Vector3(sx, 0.9, -70.6), 0.16, 2.9, IVORY.darkened(0.1), true, 10)
	box(Vector3(0, 3.9, -71.1), Vector3(4.0, 0.25, 2.0), SLATE)
	box(Vector3(0, 2.15, -71.93), Vector3(1.6, 2.6, 0.12), WALNUT)
	box(Vector3(0, 2.15, -71.86), Vector3(0.04, 2.5, 0.04), Color("#2A1E17"), 0.0, false)
	anchor("HS-ALLEY-FRONTDOOR", Vector3(0, 2.1, -71.8), ["VP-ALLEY-1"], 0.9)
	box(Vector3(0, 3.6, -71.7), Vector3(0.24, 0.34, 0.24), LAMP, 0.0, false, 2.2)
	var porch_lamp := OmniLight3D.new()
	porch_lamp.position = Vector3(0, 3.3, -71.0)
	porch_lamp.light_color = LAMP
	porch_lamp.light_energy = 1.2
	porch_lamp.omni_range = 4.0
	_geo.add_child(porch_lamp)
	# west (service) wing projects south; its SE corner has the downpipe and the rain barrel
	box(Vector3(-10.25, 3.5, -62.5), Vector3(9.5, 7.0, 19.0), PLASTER.darkened(0.05))
	gable(Vector3(-10.25, 7.0, -62.5), 19.6, 10.1, 3.0, SLATE, 0.0)
	_window_col(-5.5, -70, -54, 2.4, 4, [1])
	_window_row(-14.5, -6, -53.0, 2.4, 3, 180.0, [])
	# downpipe + overflowing barrel (HS-ALLEY-BARREL)
	cyl(Vector3(-5.35, 0.9, -53.15), 0.06, 6.1, STONE_DARK.darkened(0.2), false, 8)
	var bar := Vector3(-4.95, 0, -52.55)
	cyl(bar, 0.4, 0.92, PLANK.darkened(0.1), true, 14)
	for ry in [0.15, 0.78]:
		cyl(bar + Vector3(0, ry, 0), 0.415, 0.05, IRON, false, 14)
	cyl(bar + Vector3(0, 0.92, 0), 0.38, 0.015, WATER.lightened(0.25), false, 14)
	cyl(_gp(-4.95, -52.55, 0.005), 0.95, 0.01, GRAVEL_DARK.darkened(0.3), false, 18)   # wet ground: overflow
	anchor("HS-ALLEY-BARREL", bar + Vector3(0, 0.55, 0), ["VP-ALLEY-1"], 0.55)
	# east wing (Tarn's study) projects south along the forecourt
	box(Vector3(13, 3.75, -64), Vector3(8, 7.5, 40), PLASTER)
	gable(Vector3(13, 7.5, -64), 40.6, 8.6, 3.2, SLATE, 0.0)
	_window_col(9.0, -70, -57, 2.5, 3, [0])
	_window_col(9.0, -70, -57, 5.8, 3, [])
	# study terrace: stone platform, railing, glass double door (HS-ALLEY-TERRACE)
	box(Vector3(7.8, 0.2, -47.3), Vector3(2.4, 0.4, 3.2), STONE)
	box(Vector3(8.94, 1.6, -47.3), Vector3(0.1, 2.4, 1.6), Color("#9FB3B8"), 0.0, false, 0.35)
	box(Vector3(8.92, 1.6, -47.3), Vector3(0.12, 2.4, 0.06), IVORY.darkened(0.2), 0.0, false)
	for zz in [-48.85, -45.75]:
		box(Vector3(7.8, 0.85, zz), Vector3(2.4, 0.06, 0.06), IRON, 0.0, false)
	anchor("HS-ALLEY-TERRACE", Vector3(8.85, 1.6, -47.3), ["VP-ALLEY-1"], 0.8)
	# clock tower attached to the east wing (door without a handle; dial high and dark — not readable)
	box(Vector3(7.75, 12.0, -53.75), Vector3(4.5, 24.0, 4.5), STONE.darkened(0.05))
	box(Vector3(7.75, 24.3, -53.75), Vector3(5.0, 0.6, 5.0), STONE_DARK)
	hip(Vector3(7.75, 24.6, -53.75), 5.0, 5.0, 4.0, SLATE.darkened(0.1))
	disc(Vector3(7.75, 19.5, -51.45), 1.4, 0.08, 180.0, Color("#5A5245"))
	disc(Vector3(7.75, 19.5, -51.4), 1.2, 0.04, 180.0, Color("#6E6556"))
	box(Vector3(7.75, 1.2, -51.47), Vector3(1.1, 2.4, 0.08), WALNUT.darkened(0.1))
	box(Vector3(7.75, 2.55, -51.48), Vector3(1.5, 0.25, 0.1), STONE_DARK, 0.0, false)
	anchor("HS-ALLEY-TOWERDOOR", Vector3(7.75, 1.2, -51.4), ["VP-ALLEY-1"], 0.7)
	anchor("tower_dial", Vector3(7.75, 19.5, -51.4), [], 1.4)


func _garden_gate() -> void:
	# hedge with a wrought garden gate east of the forecourt (HS-ALLEY-GARDENGATE, boundary)
	for zz in [-43.0, -39.3]:
		box(Vector3(24, 0.85, zz), Vector3(22, 1.7, 1.1), HEDGE)
	box(Vector3(17.5, 0.85, -36), Vector3(1.1, 1.7, 6), HEDGE)
	box(Vector3(17.5, 0.85, -46.5), Vector3(1.1, 1.7, 6), HEDGE)
	for zz in [-42.2, -40.1]:
		box(Vector3(13.0, 1.0, zz), Vector3(0.45, 2.0, 0.45), STONE)
	for k in 8:
		box(Vector3(13.0, 0.95, -41.95 + k * 0.23), Vector3(0.03, 1.7, 0.03), IRON, 0.0, false)
	box(Vector3(13.0, 1.75, -41.15), Vector3(0.05, 0.06, 1.65), IRON, 0.0, false)
	anchor("HS-ALLEY-GARDENGATE", Vector3(13.0, 1.0, -41.15), ["VP-ALLEY-1"], 1.0)
	# gravel of the fork (ALLEY-01): seen from the fountain point, path to the lake starts here
	anchor("HS-ALLEY-GRAVEL", _gp(-3.9, -45.6, 0.05), ["VP-ALLEY-1"], 1.1)
	exit_mark("VP-ALLEY-1", "VP-GATE-1", 0.0, -40.8)
	exit_mark("VP-ALLEY-1", "VP-PATH-1", -6.4, -46.3)


# ------------------------------------------------------------------ lake, pier, boathouse

const PIER_P0 := Vector2(-26.5, -33.0)
const PIER_HEADING := 240.0
const PIER_LEN := 22.0
const PIER_W := 1.9
const DECK_Y := -6.3


func _pier_pt(t: float, side: float = 0.0) -> Vector3:
	var a := deg_to_rad(PIER_HEADING)
	var f := Vector2(sin(a), -cos(a))
	var r := Vector2(cos(a), sin(a))      # right of the heading
	var p := PIER_P0 + f * t + r * side
	return Vector3(p.x, DECK_Y, p.y)


func _lake_and_pier() -> void:
	# deck
	var mid := _pier_pt(PIER_LEN * 0.5)
	box(mid, Vector3(PIER_W, 0.12, PIER_LEN), PLANK_WET, PIER_HEADING)
	# piles and railings
	var t := 0.0
	while t <= PIER_LEN + 0.01:
		for side in [-PIER_W * 0.5 + 0.08, PIER_W * 0.5 - 0.08]:
			var p := _pier_pt(t, side)
			cyl(Vector3(p.x, WATER_Y - 2.5, p.z), 0.11, 2.5 + (DECK_Y - WATER_Y) + 0.95, PLANK.darkened(0.25), false, 8)
		t += 2.75
	for side in [-PIER_W * 0.5 + 0.08, PIER_W * 0.5 - 0.08]:
		var p2 := _pier_pt(PIER_LEN * 0.5, side)
		box(p2 + Vector3(0, 0.95, 0), Vector3(0.08, 0.08, PIER_LEN), PLANK.darkened(0.15), PIER_HEADING, false)
	# end of the pier: the folded coat (pale patch) with the hat on it, gull on the last pile
	var coat := _pier_pt(PIER_LEN - 1.1, 0.35)
	box(coat + Vector3(0, 0.12, 0), Vector3(0.62, 0.12, 0.48), Color("#8B8F92"), PIER_HEADING + 10.0, false)
	box(coat + Vector3(0, 0.19, 0), Vector3(0.6, 0.03, 0.46), Color("#D2CFC6"), PIER_HEADING + 10.0, false)
	cyl(coat + Vector3(0.05, 0.2, 0.02), 0.17, 0.04, Color("#2F2B28"), false, 14)
	cyl(coat + Vector3(0.05, 0.24, 0.02), 0.1, 0.11, Color("#2F2B28"), false, 14)
	var pile := _pier_pt(PIER_LEN, PIER_W * 0.5 - 0.08)
	ellipsoid(pile + Vector3(0, 1.1, 0), Vector3(0.12, 0.1, 0.22), IVORY)
	# crate under a tarpaulin, lifebuoy, rope coil, bucket at the shore end
	var crate := _pier_pt(PIER_LEN * 0.55, -0.45)
	box(crate + Vector3(0, 0.3, 0), Vector3(0.8, 0.5, 0.6), PLANK, PIER_HEADING, false)
	box(crate + Vector3(0, 0.57, 0), Vector3(0.86, 0.05, 0.66), Color("#3C4434"), PIER_HEADING, false)
	var buoy := _pier_pt(PIER_LEN * 0.33, PIER_W * 0.5)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.18
	tor.outer_radius = 0.3
	_mesh(tor, Transform3D(Basis(Vector3.UP, deg_to_rad(-PIER_HEADING)) * Basis(Vector3.FORWARD, deg_to_rad(90)), buoy + Vector3(0.05, 0.75, 0)), MAPLE.lightened(0.15))
	cyl(_pier_pt(PIER_LEN * 0.75, -0.5) + Vector3(0, 0.06, 0), 0.22, 0.08, Color("#8C7B5A"), false, 14)
	anchor("HS-PIER-SCENE", _pier_pt(PIER_LEN * 0.62) + Vector3(0, 0.3, 0), ["VP-PIER-1"], 5.5)
	anchor("pier_coat", coat + Vector3(0, 0.2, 0), ["VP-PATH-1", "VP-PIER-1"], 0.4)
	# boathouse south of the pier head: door with a padlock facing the pier (HS-PIER-SHED)
	var sc := Vector3(-27.5, -6.5, -25.0)
	var floor := box(sc + Vector3(0, 0.05, 0), Vector3(5.4, 0.1, 7.4), PLANK.darkened(0.2))
	floor.name = "ShedFloor"
	for k in 4:
		cyl(Vector3(sc.x - 2.5 + (k % 2) * 5.0, WATER_Y - 2.0, sc.z - 3.5 + (k / 2) * 7.0), 0.13, 2.6, PLANK.darkened(0.3), false, 8)
	box(sc + Vector3(0, 1.45, 0), Vector3(5.0, 2.8, 7.0), Color("#5A4636"))
	gable(sc + Vector3(0, 2.85, 0), 7.6, 5.6, 1.6, SLATE.darkened(0.05), 0.0)
	box(sc + Vector3(-2.52, 1.2, 0.5), Vector3(0.06, 2.2, 3.2), Color("#3A2D22"), 0.0, false)   # wide water door
	var door := Vector3(-27.2, -6.4, -28.53)
	box(door + Vector3(0, 1.05, 0), Vector3(1.0, 2.0, 0.06), Color("#4A3829"), 0.0, false)
	box(door + Vector3(0.32, 1.0, -0.06), Vector3(0.1, 0.14, 0.05), BRASS, 0.0, false, 0.2)
	anchor("HS-PIER-SHED", door + Vector3(0.32, 1.0, -0.08), ["VP-PIER-1"], 0.45)
	# gutter + bucket under it by the shore end of the pier (spec 3.5)
	box(sc + Vector3(0, 2.85, -3.75), Vector3(5.8, 0.1, 0.14), STONE_DARK, 0.0, false)
	cyl(Vector3(-25.3, h(-25.3, -29.3), -29.3), 0.17, 0.3, Color("#7D8084"), false, 12, 0.2)
	# path steps down to the pier head
	exit_mark("VP-PIER-1", "VP-PATH-1", -24.9, -35.4)
	var deck := _pier_pt(3.0)
	anchor("exit:VP-PATH-1>VP-PIER-1", deck + Vector3(0, 0.1, 0), ["VP-PATH-1"], 0.6)
	exit_mark("VP-PATH-1", "VP-ALLEY-1", -13.4, -45.4)
	# far shore
	for k in 9:
		var a := deg_to_rad(200.0 + k * 22.0)
		var p := Vector3(-260 + 170.0 * sin(a), -9.0, 60.0 * k - 220.0)
		ellipsoid(p, Vector3(90, 22 + 6 * (k % 3), 70), Color("#55604E"))


func _hills() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 16:
		var a := deg_to_rad(k * 22.5 + rng.randf_range(-6, 6))
		var d := rng.randf_range(380, 520)
		var p := Vector3(sin(a) * d, -12.0, -cos(a) * d)
		if p.x < -150:
			p.x -= 120
		ellipsoid(p, Vector3(rng.randf_range(110, 170), rng.randf_range(36, 60), rng.randf_range(110, 170)), Color("#59644F").lerp(Color("#6A6E5C"), rng.randf()))


# ------------------------------------------------------------------ viewpoints

func vp(id: String, x: float, z: float, heading: float, interior: bool = false, ground: float = NAN) -> void:
	var m := Marker3D.new()
	m.name = id
	var gy := h(x, z) if is_nan(ground) else ground
	m.position = Vector3(x, gy + EYE, z)
	m.set_meta("heading", heading)
	m.set_meta("interior", interior)
	_vps.add_child(m)


func _viewpoints() -> void:
	vp("VP-GATE-1", 0.0, 10.0, 0.0)                               # on the road, facing the gate
	vp("VP-GATE-2", 8.55, GH_DOOR_Z, 90.0, true, 0.06)             # inside the gatehouse, facing the keybox
	vp("VP-ALLEY-1", 0.0, -46.0, 0.0)                              # south edge of the forecourt, fountain ahead
	vp("VP-PATH-1", -18.6, -42.1, 238.0)                           # on the path down, pier below ahead
	var p := _pier_pt(1.0)
	vp("VP-PIER-1", p.x, p.z, PIER_HEADING, false, DECK_Y + 0.06)  # shore end of the pier, along it
