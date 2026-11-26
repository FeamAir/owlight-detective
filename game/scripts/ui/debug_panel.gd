class_name DebugPanel
extends Overlay
## Owner build tools (spec 8 «сборка владельца»): hotspot outlines + yaw/pitch, fast «Мысли» wait,
## start a new game from a point (to compare the three levels without replaying the prologue), protocol.

signal changed
signal start_point(level: String, sp: Dictionary)

var allow_start_points := false
var _v: VBoxContainer
var _level := "normal"


func _ready() -> void:
	add_child(UiKit.dim_layer(0.9))
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.15; scroll.anchor_right = 0.85; scroll.anchor_top = 0.04; scroll.anchor_bottom = 0.8
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_v = VBoxContainer.new()
	_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_v)
	_build()
	add_back_button()


func _onoff(b: bool) -> String:
	return Game.t("debug.on") if b else Game.t("debug.off")


func _build() -> void:
	for c in _v.get_children():
		c.queue_free()
	_v.add_child(UiKit.label(Game.t("debug.title"), UiKit.FONT_UI + 8, UiKit.LAMP))
	var ov := UiKit.button(Game.t("debug.overlay", {"v": _onoff(Game.settings["debug_overlay"])}))
	ov.pressed.connect(func() -> void:
		Game.settings["debug_overlay"] = not Game.settings["debug_overlay"]
		Game.save_settings()
		changed.emit()
		_build())
	_v.add_child(ov)
	var secs := int(Game.data.debug_profile().get("hint_wait_seconds_fast", 10))
	var fh := UiKit.button(Game.t("debug.fast_hints", {"s": secs, "v": _onoff(Game.settings["debug_fast_hints"])}))
	fh.pressed.connect(func() -> void:
		Game.settings["debug_fast_hints"] = not Game.settings["debug_fast_hints"]
		Game.save_settings()
		changed.emit()
		_build())
	_v.add_child(fh)
	if Game.state != null:
		var proto := UiKit.label(Game.protocol_text(), UiKit.FONT_UI - 8, UiKit.FOG)
		_v.add_child(proto)
	if not allow_start_points:
		return
	var row := HBoxContainer.new()
	for lvl in GameData.LEVELS:
		var b := UiKit.button(Game.t("diff." + lvl) + (" ✓" if lvl == _level else ""))
		b.pressed.connect(func() -> void:
			_level = lvl
			_build())
		row.add_child(b)
	_v.add_child(UiKit.label(Game.t("debug.start_from", {"d": Game.t("diff." + _level)})))
	_v.add_child(row)
	for sp in Game.data.slice().get("debug", {}).get("start_points", []):
		var b2 := UiKit.button(Game.t(sp["label_key"]))
		b2.pressed.connect(func() -> void: start_point.emit(_level, sp))
		_v.add_child(b2)
