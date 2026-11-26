class_name PauseMenu
extends Overlay
## Pause (дизайн 3.14): resume / settings / main menu; owner build — debug panel.

signal main_menu
signal settings_changed


func _ready() -> void:
	add_child(UiKit.dim_layer(0.7))
	var v := VBoxContainer.new()
	v.anchor_left = 0.5; v.anchor_right = 0.5; v.anchor_top = 0.5; v.anchor_bottom = 0.5
	v.offset_left = -300; v.offset_right = 300; v.offset_top = -300; v.offset_bottom = 300
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(v)
	var title := UiKit.label(Game.t("pause.title"), UiKit.FONT_TITLE, UiKit.LAMP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume := UiKit.button(Game.t("pause.resume"), 600, true)
	resume.pressed.connect(close)
	v.add_child(resume)
	var st := UiKit.button(Game.t("pause.settings"), 600)
	st.pressed.connect(func() -> void:
		var sp := SettingsPanel.new()
		sp.changed.connect(func() -> void: settings_changed.emit())
		add_child(sp))
	v.add_child(st)
	if Game.debug_build:
		var dbg := UiKit.button(Game.t("menu.debug"), 600)
		dbg.pressed.connect(func() -> void:
			var dp := DebugPanel.new()
			dp.changed.connect(func() -> void: settings_changed.emit())
			add_child(dp))
		v.add_child(dbg)
	var mm := UiKit.button(Game.t("pause.main_menu"), 600)
	mm.pressed.connect(func() -> void:
		main_menu.emit()
		close())
	v.add_child(mm)
	var info := UiKit.label(Game.t("pause.saved_ago"), UiKit.FONT_UI - 4, UiKit.FOG)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(info)


func on_back() -> bool:
	for c in get_children():
		if c is Overlay:
			c.on_back()
			return true
	close()
	return true
