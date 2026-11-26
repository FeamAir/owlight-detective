class_name ClockLockLogic
extends RefCounted
## PZ-GATE-03 (T19): key box with a clock-face lock. The hands must show the train's arrival time
## (departure + journey from the ticket). 12-hour dial: 09:40 and 21:40 are the same position.
## Values: values/<profile>.yaml → PZ-GATE-03 (departure, duration_min | legs_min, snap_minutes, target_time, decoys).
## Time on the dial is minutes 0…719 (0 = 12:00).

const DIAL := 720


static func to_min(hhmm: String) -> int:
	var p := hhmm.split(":")
	if p.size() != 2:
		return -1
	return int(p[0]) * 60 + int(p[1])


static func dial(t: int) -> int:
	return posmod(t, DIAL)


static func fmt(t: int) -> String:
	var d := dial(t)
	var h := d / 60
	return "%02d:%02d" % [12 if h == 0 else h, d % 60]


static func duration(v: Dictionary) -> int:
	if v.has("legs_min"):
		var s := 0
		for x in v["legs_min"]:
			s += int(x)
		return s
	return int(v.get("duration_min", 0))


## Arrival computed from the ticket (must equal target_time — checked by tests and data_build).
static func arrival(v: Dictionary) -> int:
	return to_min(str(v.get("departure", "00:00"))) + duration(v)


static func target(v: Dictionary) -> int:
	return to_min(str(v.get("target_time", "00:00")))


static func snap_step(v: Dictionary) -> int:
	return maxi(1, int(v.get("snap_minutes", 5)))


## Rounds a dial time to the level's step (Л 10 min, Н 5, С 1).
static func snap(t: int, v: Dictionary) -> int:
	var st := snap_step(v)
	return dial(int(round(float(t) / st)) * st)


static func is_correct(t: int, v: Dictionary) -> bool:
	return dial(t) == dial(target(v))


## Classifies a dial time by the rule names in progression.yaml (PZ-GATE-03 feedback_rules).
static func classify(t: int, v: Dictionary) -> String:
	var d := dial(t)
	var goal := dial(target(v))
	if d == goal:
		return "correct"
	if d == dial(to_min(str(v.get("departure", "")))):
		return "departure"
	if d == dial(duration(v)):
		return "duration"
	var decoys: Dictionary = v.get("decoys", {})
	if d == 0 or (decoys.has("wall_clock") and d == dial(to_min(str(decoys["wall_clock"])))):
		return "now"
	if decoys.has("ticket_no"):
		var tn := str(decoys["ticket_no"])
		if tn.length() == 4 and d == dial(to_min(tn.substr(0, 2) + ":" + tn.substr(2, 2))):
			return "ticket_no"
	var diff := absi(d - goal)
	diff = mini(diff, DIAL - diff)
	if diff <= 15 or diff == 60:
		return "near"
	return "other"


## Hand angles (radians, 0 = 12 o'clock, clockwise).
static func hour_angle(t: int) -> float:
	return TAU * float(dial(t)) / DIAL


static func minute_angle(t: int) -> float:
	return TAU * float(posmod(t, 60)) / 60.0


## New time after dragging the minute hand to an angle: minutes follow the angle, the hour
## carries over when the hand passes 12 (like a real clock).
static func drag_minute(t: int, angle: float, v: Dictionary) -> int:
	var m := int(round(fposmod(angle, TAU) / TAU * 60.0)) % 60
	var old_m := posmod(t, 60)
	var h := dial(t) / 60
	if old_m >= 45 and m < 15:
		h += 1
	elif old_m < 15 and m >= 45:
		h -= 1
	return snap(h * 60 + m, v)


## New time after dragging the hour hand: the nearest hour, minutes kept.
static func drag_hour(t: int, angle: float) -> int:
	var h := int(round(fposmod(angle, TAU) / TAU * 12.0)) % 12
	return dial(h * 60 + posmod(t, 60))


## LOGIC-GATE-03 template parameters ({departure}, {duration}, {arrival}) in words from values.
static func logic_params(v: Dictionary, lang: String) -> Dictionary:
	var w: Dictionary = v.get("logic_words", {}).get(lang, {})
	return {"departure": str(w.get("departure", v.get("departure", ""))),
			"duration": str(w.get("duration", "")),
			"arrival": str(w.get("arrival", v.get("target_time", "")))}
