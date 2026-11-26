class_name LogPanel
extends Control
## Dialogue log (дизайн 3.9): panel on the right, 60 % width, newest at the bottom.


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := UiKit.dim_layer(0.4)
	bg.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			queue_free())
	add_child(bg)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.4; panel.anchor_right = 1.0; panel.anchor_bottom = 1.0
	add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(UiKit.label(Game.t("nb.tab.log"), UiKit.FONT_UI + 4, UiKit.LAMP))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var close := UiKit.button(Game.t("btn.close"))
	close.pressed.connect(queue_free)
	top.add_child(close)
	v.add_child(top)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var r := UiKit.rich(UiKit.FONT_UI)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var parts: Array = []
	for id in Game.state.line_log:
		var ln := Game.data.line(id)
		var t := UiKit.escape_bb(Game.line(id))
		if ln.get("style") == "thought":
			t = "[i]%s[/i]" % t
		parts.append("[color=#F2C98A]%s[/color]\n%s" % [Game.speaker_name(id), t])
	r.text = "\n\n".join(parts) if not parts.is_empty() else Game.t("nb.empty")
	scroll.add_child(r)
	_scroll_end(scroll)


func _scroll_end(scroll: ScrollContainer) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
