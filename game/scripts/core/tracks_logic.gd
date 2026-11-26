class_name TracksLogic
extends RefCounted
## PZ-ALLEY-01 (T16): prints on the gravel fork. A tap on a print marks its whole chain or group
## (select_mode: group), a marked chain gets a direction toggle "to the lake / to the drive".
## "Done" checks (a) which groups are marked and (b) the direction of each chain (spec 5.3).
## Values: values/<profile>.yaml → PZ-ALLEY-01 (chains, overlap, washed_pits, extra_decoys, answer).
##
## The layout is generated here from the values, in a fixed design space 1600×720 (top = path to the lake,
## bottom = the main drive), so the screen only scales it. Deterministic: the same values give the same picture.

const W := 1600.0
const H := 720.0
const PATH_X := Vector2(520, 1080)       # gravel path to the lake (x range)
const PATH_Y := Vector2(40, 520)         # where chains and washed pits are
const TRAMPLED := Rect2(560, 528, 480, 70)
const RUTS := Rect2(0, 606, 1600, 100)
const GROUPS_FIXED := ["pits", "ruts", "trampled", "gull"]


static func chains(v: Dictionary) -> Array:
	return Array(v.get("chains", []))


static func chain_ids(v: Dictionary) -> Array:
	return chains(v).map(func(c: Dictionary) -> String: return str(c["id"]))


static func print_length(level: String) -> float:
	return 128.0 if level == "easy" else 96.0     # ≥ 64 dp on easy, ≥ 48 dp otherwise (визуальное ТЗ 5.3)


static func _chain_x(side: String, overlap: String) -> float:
	var off := {"none": 180.0, "partial": 80.0, "heavy": 40.0}
	var d: float = off.get(overlap, 80.0)
	return 800.0 - d if side == "left" else 800.0 + d


## Layout: {prints: [{group, pos, dir (+1 toe up / -1 toe down), foot, toe_only, len}],
##          pits: [{pos, r}], gull: [{pos, rot}], trampled: Rect2, ruts: Rect2}
static func layout(v: Dictionary, level: String) -> Dictionary:
	var out := {"prints": [], "pits": [], "gull": [], "trampled": TRAMPLED, "ruts": RUTS}
	var plen := print_length(level)
	var overlap := str(v.get("overlap", "none"))
	for c in chains(v):
		var n := int(c.get("prints", 6))
		var dir := 1 if c.get("dir") == "to_pier" else -1
		var x0 := _chain_x(str(c.get("side", "left")), overlap)
		var span := PATH_Y.y - PATH_Y.x - plen
		# heavy overlap: the right chain is shifted by half a step, so its prints fall between the left ones
		var shift := span / maxf(1.0, n - 1) * 0.5 if (overlap == "heavy" and c.get("side") == "right") else 0.0
		var step := (span - shift) / maxf(1.0, n - 1)
		var toe_only := int(c.get("toe_only", 0))
		for i in n:
			# walking order: to the lake starts at the bottom; to the drive starts at the top
			var k := i if dir == 1 else n - 1 - i
			var y := PATH_Y.y - plen * 0.5 - shift - step * k
			var foot := -1 if i % 2 == 0 else 1
			var pos := Vector2(x0 + foot * plen * 0.36, y)
			var t_only := toe_only > 0 and i in [2, 4, 6].slice(0, toe_only)
			out["prints"].append({"group": str(c["id"]), "pos": pos, "dir": dir, "foot": foot,
					"toe_only": t_only, "len": plen})
	# washed pits: grid candidates away from prints, deterministic shuffle
	var cand: Array = []
	var gx := PATH_X.x + 40.0
	while gx <= PATH_X.y - 40.0:
		var gy := PATH_Y.x + 40.0
		while gy <= PATH_Y.y - 30.0:
			var ok := true
			for p in out["prints"]:
				if (p["pos"] as Vector2).distance_to(Vector2(gx, gy)) < plen * 0.75:
					ok = false
					break
			if ok:
				cand.append(Vector2(gx, gy))
			gy += 56.0
		gx += 56.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1015                      # fixed: the same picture every time
	for i in range(cand.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Vector2 = cand[i]
		cand[i] = cand[j]
		cand[j] = tmp
	var want := int(v.get("washed_pits", 0))
	for p in cand:
		if out["pits"].size() >= want:
			break
		var far := true
		for q in out["pits"]:
			if (q["pos"] as Vector2).distance_to(p) < 100.0:
				far = false
				break
		if far:
			out["pits"].append({"pos": p, "r": 30.0})
	if "gull_tracks" in v.get("extra_decoys", []):
		for i in 6:
			out["gull"].append({"pos": Vector2(600 + i * 80, 130 + i * 52), "rot": 0.6})
	return out


## Group under a design-space point ("" if none): nearest print / pit / gull mark, then trampled, then ruts.
static func hit(lay: Dictionary, p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for pr in lay["prints"]:
		var d := (pr["pos"] as Vector2).distance_to(p)
		if d < float(pr["len"]) * 0.55 and d < best_d:
			best_d = d
			best = pr["group"]
	for pt in lay["pits"]:
		var d2 := (pt["pos"] as Vector2).distance_to(p)
		if d2 < 48.0 and d2 < best_d:
			best_d = d2
			best = "pits"
	for g in lay["gull"]:
		var d3 := (g["pos"] as Vector2).distance_to(p)
		if d3 < 44.0 and d3 < best_d:
			best_d = d3
			best = "gull"
	if best != "":
		return best
	if (lay["trampled"] as Rect2).has_point(p):
		return "trampled"
	if (lay["ruts"] as Rect2).has_point(p):
		return "ruts"
	return ""


## Toggle: unset → to_pier → to_alley → to_pier …
static func next_dir(cur: String) -> String:
	return "to_alley" if cur == "to_pier" else "to_pier"


## Check: {ok, rule, n, m}. rule — progression feedback_rules name for the first problem found
## (pits, ruts, trampled, gull, one_chain, direction); n of m=2 parts correct (marked groups, directions).
static func check(selected: Array, dirs: Dictionary, v: Dictionary) -> Dictionary:
	var ans: Dictionary = v.get("answer", {})
	var fresh: Array = Array(ans.get("fresh", []))
	var want_dir: Dictionary = ans.get("dir", {})
	var sel := {}
	for s in selected:
		sel[str(s)] = true
	var part_a := sel.size() == fresh.size()
	for f in fresh:
		if not sel.has(f):
			part_a = false
	var part_b := true
	for f in fresh:
		if not sel.has(f) or str(dirs.get(f, "")) != str(want_dir.get(f, "")):
			part_b = false
	var res := {"ok": part_a and part_b, "rule": "correct", "n": int(part_a) + int(part_b), "m": 2}
	if res["ok"]:
		return res
	for g in GROUPS_FIXED:
		if sel.has(g):
			res["rule"] = g
			return res
	for f in fresh:
		if not sel.has(f):
			res["rule"] = "one_chain"
			return res
	res["rule"] = "direction"
	return res
