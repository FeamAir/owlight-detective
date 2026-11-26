class_name SearchLogic
extends RefCounted
## PZ-PIER-01 (T08): search scene with a list of silhouettes. A tap on an object that matches a target
## of the level marks it found; a tap on a look-alike gives a reaction by level; a wrong tap costs nothing.
## Values: values/<profile>.yaml → PZ-PIER-01 (targets, described, counter, clutter_extra).
## Layout: data/puzzles/layouts.yaml → PZ-PIER-01.objects (rect in scene fractions).


static func targets(v: Dictionary) -> Array:
	return Array(v.get("targets", []))


## Objects present at the level (levels: […] filter).
static func objects(layout: Dictionary, level: String) -> Array:
	var out: Array = []
	for o in layout.get("objects", []):
		if o.has("levels") and not (level in o["levels"]):
			continue
		out.append(o)
	return out


static func _rect(o: Dictionary) -> Rect2:
	var r: Array = o.get("rect", [0, 0, 0, 0])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## Object under a point (scene fractions): smallest zone first, background zones last. {} if none.
static func hit(layout: Dictionary, level: String, p: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_area := INF
	var bg: Dictionary = {}
	for o in objects(layout, level):
		var r := _rect(o)
		if not r.has_point(p):
			continue
		if o.get("background", false):
			bg = o
			continue
		var a := r.get_area()
		if a < best_area:
			best_area = a
			best = o
	return best if not best.is_empty() else bg


## Result of a tap on an object:
##   {kind: "found" | "already" | "reaction" | "none", target, rule}
## found — a new target; reaction — a look-alike with a rule (progression feedback_rules); none — scenery.
## selected — silhouette the player picked in the list ("" if none).
static func tap(obj: Dictionary, found: Array, v: Dictionary, selected: String = "") -> Dictionary:
	var res := {"kind": "none", "target": "", "rule": ""}
	if obj.is_empty():
		return res
	var tg := str(obj.get("target", ""))
	if tg != "" and tg in targets(v):
		if not (tg in found):
			res["kind"] = "found"
			res["target"] = tg
			return res
		# found already: tapping the coat body again while the damp hem is still missing (test-set risk 2)
		var rif: Dictionary = obj.get("rule_if_found", {})
		for t in rif:
			if t in targets(v) and not (t in found):
				res["kind"] = "reaction"
				res["rule"] = str(rif[t])
				return res
		res["kind"] = "already"
		res["target"] = tg
		return res
	var ris: Dictionary = obj.get("rule_if_selected", {})
	if selected != "" and ris.has(selected) and not (selected in found):
		res["kind"] = "reaction"
		res["rule"] = str(ris[selected])
		return res
	if obj.has("rule"):
		res["kind"] = "reaction"
		res["rule"] = str(obj["rule"])
	return res


static func is_complete(found: Array, v: Dictionary) -> bool:
	for t in targets(v):
		if not (t in found):
			return false
	return true


## How a target is shown in the list: "silhouette" or "description" (hard: two by description).
static func list_kind(target: String, v: Dictionary) -> String:
	return "description" if target in v.get("described", []) else "silhouette"


static func shows_counter(v: Dictionary) -> bool:
	return bool(v.get("counter", false))
