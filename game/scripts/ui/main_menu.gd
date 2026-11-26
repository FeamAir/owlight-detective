class_name MainMenu
extends Control
## Main screen (дизайн 3.2): title on the left, button column on the right (Continue only with a save).

signal continue_game
signal new_game
signal debug_start(level: String, sp: Dictionary)

var _col: VBoxContainer


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := PanoramaView.new()
	UiKit.full_rect(bg)
	bg.interactive = false
	add_child(bg)
	bg.set_texture(Game.data.texture("pano", "pan_pier_n1_day"))
	bg.look_at_angles(300, 5)
	bg.dim = 0.45
	var title := UiKit.label(Game.t("menu.title"), 84, UiKit.LAMP)
	title.position = Vector2(80, 80)
	title.size = Vector2(700, 120)
	title.add_theme_color_override("font_outline_color", UiKit.INK)
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)
	var sub := UiKit.label(Game.t("menu.subtitle"), UiKit.FONT_UI, UiKit.IVORY)
	sub.position = Vector2(84, 200)
	sub.size = Vector2(700, 50)
	add_child(sub)
	_col = VBoxContainer.new()
	_col.anchor_left = 1.0; _col.anchor_right = 1.0; _col.anchor_top = 0.5; _col.anchor_bottom = 0.5
	_col.offset_left = -560; _col.offset_right = -60; _col.offset_top = -260; _col.offset_bottom = 260
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_col)
	_build()
	Game.language_changed.connect(_build)


func _build() -> void:
	for c in _col.get_children():
		c.queue_free()
	if Game.has_save():
		var b := UiKit.button(Game.t("menu.continue"), 500, true)
		b.custom_minimum_size.y = UiKit.BIG_TAP
		b.pressed.connect(func() -> void: continue_game.emit())
		_col.add_child(b)
		var s := Game.save_summary()
		if not s.is_empty():
			var info := UiKit.label(Game.t("menu.save_info", {"difficulty": Game.t("diff." + str(s.get("difficulty", ""))),
				"time": Game.format_time(float(s.get("play_time", 0)))}), UiKit.FONT_UI - 6, UiKit.FOG)
			_col.add_child(info)
	var n := UiKit.button(Game.t("menu.new_game"), 500, not Game.has_save())
	n.custom_minimum_size.y = UiKit.BIG_TAP
	n.pressed.connect(func() -> void: new_game.emit())
	_col.add_child(n)
	var st := UiKit.button(Game.t("menu.settings"), 500)
	st.pressed.connect(func() -> void: add_child(SettingsPanel.new()))
	_col.add_child(st)
	if Game.debug_build:
		var d := UiKit.button(Game.t("menu.debug"), 500)
		d.pressed.connect(func() -> void:
			var dp := DebugPanel.new()
			dp.allow_start_points = true
			dp.start_point.connect(func(lvl: String, sp: Dictionary) -> void: debug_start.emit(lvl, sp))
			add_child(dp))
		_col.add_child(d)


func on_back() -> void:
	for c in get_children():
		if c is Overlay:
			c.on_back()
			return
	get_tree().quit()
