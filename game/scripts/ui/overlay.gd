class_name Overlay
extends Control
## Base for full-screen layers over the panorama. Android "Back" closes the top overlay (дизайн 2.4).

signal closed

## false — the panorama under this overlay stays interactive (bag tray, дизайн 3.7).
var blocks_view := true


func _init() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Returns true when handled.
func on_back() -> bool:
	close()
	return true


func close() -> void:
	closed.emit()
	queue_free()


func add_back_button() -> Button:
	var b := UiKit.button(Game.t("btn.back"), 220)
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = 24
	b.offset_right = 244
	b.offset_top = -24 - UiKit.BIG_TAP
	b.offset_bottom = -24
	b.custom_minimum_size.y = UiKit.BIG_TAP
	b.pressed.connect(on_back)
	add_child(b)
	return b


func add_title(text: String) -> Label:
	var l := UiKit.label(text, UiKit.FONT_UI + 8, UiKit.LAMP)
	l.anchor_right = 1.0
	l.offset_left = 140
	l.offset_right = -260
	l.offset_top = 24
	l.offset_bottom = 90
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l
