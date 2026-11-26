class_name BagPanel
extends Overlay
## Bag tray (дизайн 3.7): slides from the bottom, the panorama stays visible above.
## Tap = select (name above the tray), tap again = examine. The owl is fixed in slot 1.
## Combining / dragging onto the scene: not needed in slice 01 (no item is applied by drag here).

var _selected := ""
var _name: Label
var _slots: HBoxContainer


func _ready() -> void:
	blocks_view = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tray := PanelContainer.new()
	tray.anchor_top = 1.0; tray.anchor_bottom = 1.0; tray.anchor_right = 1.0
	tray.offset_left = 260; tray.offset_right = -260; tray.offset_top = -330; tray.offset_bottom = -12
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(tray)
	var v := VBoxContainer.new()
	tray.add_child(v)
	var top := HBoxContainer.new()
	_name = UiKit.label(Game.t("bag.hint"), UiKit.FONT_UI, UiKit.LAMP)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_name)
	var close_b := UiKit.button("✕", UiKit.TAP)
	close_b.pressed.connect(close)
	top.add_child(close_b)
	v.add_child(top)
	_slots = HBoxContainer.new()
	v.add_child(_slots)
	Game.state.news["bag"] = 0
	_fill()


func _fill() -> void:
	for c in _slots.get_children():
		c.queue_free()
	var items: Array = Game.state.inventory.duplicate()
	items.sort_custom(func(a: String, b: String) -> bool:
		return int(Game.data.item(a).get("slot_fixed", 99)) < int(Game.data.item(b).get("slot_fixed", 99)))
	for id in items:
		var b := Button.new()
		b.custom_minimum_size = Vector2(128, 128)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = Game.data.texture("items", Game.data.item(id).get("inspect", {}).get("asset", ""))
		b.expand_icon = true
		b.toggle_mode = true
		b.button_pressed = id == _selected
		b.pressed.connect(_tap.bind(id))
		_slots.add_child(b)


func _tap(id: String) -> void:
	if _selected == id:
		get_parent().add_child(ItemInspect.new().setup(id))
		return
	_selected = id
	_name.text = Game.t(Game.data.item(id).get("name_key", id))
	_fill()
