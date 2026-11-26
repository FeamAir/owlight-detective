class_name SettingsPanel
extends Overlay
## Settings in the slice: language RU/EN, text speed. (Sound, FOV, text size, accessibility — later.)

signal changed

var _v: VBoxContainer


func _ready() -> void:
	add_child(UiKit.dim_layer(0.85))
	_v = VBoxContainer.new()
	_v.anchor_left = 0.5; _v.anchor_right = 0.5; _v.anchor_top = 0.5; _v.anchor_bottom = 0.5
	_v.offset_left = -360; _v.offset_right = 360; _v.offset_top = -260; _v.offset_bottom = 260
	_v.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_v)
	_build()
	add_back_button()


func _build() -> void:
	for c in _v.get_children():
		c.queue_free()
	_v.add_child(UiKit.label(Game.t("settings.title"), UiKit.FONT_TITLE, UiKit.LAMP))
	var lang := UiKit.button(Game.t("settings.language") + "  ⇄", 720)
	lang.pressed.connect(func() -> void:
		Game.set_language("en" if Game.lang() == "ru" else "ru")
		changed.emit()
		_build())
	_v.add_child(lang)
	var speed := UiKit.button(Game.t("settings.text_speed", {"v": Game.t("settings.speed." + Game.settings["text_speed"])}), 720)
	speed.pressed.connect(func() -> void:
		var order := ["fast", "normal", "instant"]
		Game.settings["text_speed"] = order[(order.find(Game.settings["text_speed"]) + 1) % order.size()]
		Game.save_settings()
		_build())
	_v.add_child(speed)
