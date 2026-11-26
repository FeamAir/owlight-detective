class_name CompareLogic
extends RefCounted
## PZ-GATE-02 (T15): "compare" mode. Pick two fragments from the documents (weather tape, notes from the
## pier, weather log, on hard also the gate tape) and one of four conclusions. Correct = one fragment from
## answer.rain + one from answer.items_any + the right conclusion (spec 5.4).
## Values: values/<profile>.yaml → PZ-GATE-02 (tape.segments, journal, notes, extra_docs, answer, roles).

const DOC_ORDER := ["tape", "notes", "journal", "gate"]


## Gate-tape marks as fragment ids: "14 Oct 23:10" → gate_14_2310.
static func gate_marks(snap_values: Dictionary) -> Array:
	var out: Array = []
	for day in ["14", "15"]:
		for t in snap_values.get("marks_" + day, []):
			out.append({"id": "gate_%s_%s" % [day, str(t).replace(":", "")], "day": day, "time": str(t)})
	return out


## Selectable fragments: [{id, doc}] in document order.
static func fragments(v: Dictionary, snap_values: Dictionary = {}) -> Array:
	var out: Array = []
	for s in v.get("tape", {}).get("segments", []):
		out.append({"id": str(s["id"]), "doc": "tape"})
	for n in v.get("notes", []):
		out.append({"id": str(n), "doc": "notes"})
	if v.get("journal_in_pool", true):
		for j in v.get("journal", []):
			out.append({"id": str(j), "doc": "journal"})
	if "SNAP-GATE-TAPE" in v.get("extra_docs", []):
		for m in gate_marks(snap_values):
			out.append({"id": m["id"], "doc": "gate"})
	return out


static func docs(v: Dictionary, snap_values: Dictionary = {}) -> Array:
	var have := {}
	for f in fragments(v, snap_values):
		have[f["doc"]] = true
	return DOC_ORDER.filter(func(d: String) -> bool: return have.has(d))


static func doc_of(frag: String, v: Dictionary) -> String:
	for s in v.get("tape", {}).get("segments", []):
		if str(s["id"]) == frag:
			return "tape"
	if frag in v.get("notes", []):
		return "notes"
	if frag in v.get("journal", []):
		return "journal"
	if frag.begins_with("gate_"):
		return "gate"
	return ""


## Role of a wrong fragment → feedback rule name.
static func fragment_rule(frag: String, v: Dictionary) -> String:
	var roles: Dictionary = v.get("roles", {})
	if roles.has(frag):
		return str(roles[frag])
	match doc_of(frag, v):
		"tape":
			return "tape_wrong"
		"journal":
			return "journal"
		"gate":
			return "decoy_doc"
	return "other"


static func conclusions(v: Dictionary) -> Array:
	return Array(v.get("conclusions", ["A", "B", "C", "D"])).map(func(c: Variant) -> String: return str(c).substr(0, 1))


## "Done" is active: exactly two fragments and a conclusion.
static func can_submit(selected: Array, conclusion: String) -> bool:
	return selected.size() == 2 and conclusion != ""


const RULE_ORDER := ["hem", "rain_evidence", "folded", "tape_wrong", "journal", "decoy_doc", "other"]


## {ok, rule, n, m: 3, keep: [fragments that are right], keep_conclusion: bool}
static func check(selected: Array, conclusion: String, v: Dictionary) -> Dictionary:
	var ans: Dictionary = v.get("answer", {})
	var rain: Array = Array(ans.get("rain", []))
	var items: Array = Array(ans.get("items_any", []))
	var rain_ok := false
	var item_ok := false
	var keep: Array = []
	var faults: Array = []
	for f in selected:
		if f in rain and not rain_ok:
			rain_ok = true
			keep.append(f)
		elif f in items:
			if not item_ok:          # "top dry" and "hat dry" prove the same: the second one is no fault
				item_ok = true
				keep.append(f)
		else:
			faults.append(fragment_rule(str(f), v))
	var concl_ok := conclusion != "" and conclusion.substr(0, 1) == str(ans.get("conclusion", "")).substr(0, 1)
	var res := {"ok": rain_ok and item_ok and concl_ok and selected.size() == 2, "rule": "correct",
			"n": int(rain_ok) + int(item_ok) + int(concl_ok), "m": 3, "keep": keep, "keep_conclusion": concl_ok}
	if res["ok"]:
		return res
	if rain_ok and item_ok:
		res["rule"] = "wrong_conclusion"
		return res
	for r in RULE_ORDER:
		if r in faults:
			res["rule"] = r
			return res
	res["rule"] = "tape_wrong"     # no fault named, but the night on the tape is missing
	return res


# ------------------------------------------------------------ the weather tape (time axis)

const TAPE_EPOCH_DAY := 10        # hours on the tape are counted from 10 Oct 00:00
const POINT_HALF_H := 0.7         # "pen went up / down" fragments: ±0.7 h around the moment (≈ 50 dp at 72 px/h)


## "13 Oct 18:00" → hours since 10 Oct 00:00.
static func tape_hour(s: String) -> float:
	var p := s.split(" ", false)
	if p.size() < 3:
		return 0.0
	var hm := p[2].split(":")
	return (int(p[0]) - TAPE_EPOCH_DAY) * 24.0 + int(hm[0]) + int(hm[1]) / 60.0


## Selectable zones on the tape: [{id, kind, from, to, height}] (hours). Points become narrow zones.
static func tape_zones(v: Dictionary) -> Array:
	var out: Array = []
	for s in v.get("tape", {}).get("segments", []):
		var z := {"id": str(s["id"]), "kind": str(s.get("kind", "rain")), "height": str(s.get("height", "high"))}
		if s.has("at"):
			var h := tape_hour(str(s["at"]))
			z["from"] = h - POINT_HALF_H
			z["to"] = h + POINT_HALF_H
			z["at"] = h
		else:
			z["from"] = tape_hour(str(s["from"]))
			z["to"] = tape_hour(str(s["to"]))
		out.append(z)
	# a range that contains point zones gives way to them: its own zone is trimmed to the middle part
	for z in out:
		if z.has("at"):
			continue
		for p in out:
			if p.has("at") and p["at"] >= z["from"] - 0.01 and p["at"] <= z["to"] + 0.01:
				if absf(p["at"] - z["from"]) < 0.01:
					z["from"] = p["to"]
				elif absf(p["at"] - z["to"]) < 0.01:
					z["to"] = p["from"]
	return out


## Zone id at an hour ("" if none); narrow (point) zones win.
static func tape_hit(zones: Array, hour: float) -> String:
	var best := ""
	var best_w := INF
	for z in zones:
		if hour >= z["from"] and hour <= z["to"]:
			var w: float = z["to"] - z["from"]
			if w < best_w:
				best_w = w
				best = z["id"]
	return best


## Rain intervals drawn by the upper pen: [{from, to, height}] (points are not separate rain).
static func rain_spans(v: Dictionary) -> Array:
	var out: Array = []
	for s in v.get("tape", {}).get("segments", []):
		if str(s.get("kind", "")) == "rain":
			out.append({"from": tape_hour(str(s["from"])), "to": tape_hour(str(s["to"])), "height": str(s.get("height", "high"))})
	return out
