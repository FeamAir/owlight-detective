class_name ContinueHint
extends PanelContainer
## «Нажмите, чтобы продолжить ▸» on a small plate: readable over any art. Calm at first, then a soft pulse
## if the player has not tapped for PULSE_AFTER seconds (owner 28.11). restart() — new line/frame.

const PULSE_AFTER := 1.5

var _label: Label
var _t := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiKit.LAKE_DUSK, 0.8)
	sb.border_color = Color(UiKit.BRASS, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22; sb.content_margin_right = 22; sb.content_margin_top = 6; sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)
	_label = UiKit.label("", UiKit.FONT_UI - 4, UiKit.LAMP)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _ready() -> void:
	_label.text = Game.t("ui.tap_continue")
	Game.language_changed.connect(func() -> void: _label.text = Game.t("ui.tap_continue"))


func text() -> String:
	return _label.text


func restart() -> void:
	_t = 0.0
	modulate.a = 1.0


func pulsing() -> bool:
	return _t >= PULSE_AFTER


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _t < PULSE_AFTER:
		modulate.a = 0.9
	else:
		modulate.a = 0.65 + 0.35 * (0.5 + 0.5 * sin((_t - PULSE_AFTER) * TAU * 0.8))
